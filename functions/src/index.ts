
import {initializeApp, getApps} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

setGlobalOptions({maxInstances: 10});

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const DELIVERY_LEASE_MS = 2 * 60 * 1000;

type ClaimResult = "sent" | "busy" | "claimed";

function getErrorCode(error: unknown): string | undefined {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof error.code === "string"
  ) {
    return error.code;
  }

  return undefined;
}

export const notifyFamilyOnSos = onDocumentCreated(
  {
    document: "families/{familyId}/emergencies/{emergencyId}",
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const emergency = snapshot.data();

    if (emergency.status !== "active") {
      console.log(
        `SOS ${event.params.emergencyId}: ignored because status is not active.`,
      );
      return;
    }

    const familyId = event.params.familyId;
    const emergencyId = event.params.emergencyId;
    const senderUid = emergency.createdBy;

    if (typeof senderUid !== "string" || senderUid.length === 0) {
      console.error("SOS has no valid createdBy UID:", emergencyId);
      return;
    }

    const senderName =
      typeof emergency.senderName === "string" &&
      emergency.senderName.trim().length > 0
        ? emergency.senderName.trim()
        : "A family member";

    const membersSnapshot = await db
      .collection("families")
      .doc(familyId)
      .collection("members")
      .where("status", "==", "active")
      .get();

    const recipientUids = new Set<string>();

    for (const member of membersSnapshot.docs) {
      const memberData = member.data();

      const uid =
        typeof memberData.uid === "string" &&
        memberData.uid.length > 0
          ? memberData.uid
          : member.id;

      if (uid !== senderUid) {
        recipientUids.add(uid);
      }
    }

    if (recipientUids.size === 0) {
      console.log(
        `SOS ${emergencyId}: no other active family members to notify.`,
      );
      return;
    }

    const memberResults = await Promise.allSettled(
      [...recipientUids].map(async (uid) => {
        const devicesSnapshot = await db
          .collection("users")
          .doc(uid)
          .collection("devices")
          .get();

        const validDevices = devicesSnapshot.docs.filter((deviceDoc) => {
          const device = deviceDoc.data();
          return typeof device.fid === "string" && device.fid.length > 0;
        });

        const deviceResults = await Promise.allSettled(
          validDevices.map(async (deviceDoc) => {
            const device = deviceDoc.data();
            const fid = device.fid as string;

            const deliveryRef = snapshot.ref
              .collection("notificationDeliveries")
              .doc(deviceDoc.id);

            // Claim delivery atomically to reduce duplicate sends.
            const claimResult: ClaimResult = await db.runTransaction(
              async (transaction): Promise<ClaimResult> => {
                const deliverySnapshot =
                  await transaction.get(deliveryRef);
                const delivery = deliverySnapshot.data();

                if (delivery?.status === "sent") {
                  return "sent";
                }

                const leaseUntilMs =
                  typeof delivery?.leaseUntilMs === "number"
                    ? delivery.leaseUntilMs
                    : 0;

                if (
                  delivery?.status === "sending" &&
                  leaseUntilMs > Date.now()
                ) {
                  return "busy";
                }

                transaction.set(
                  deliveryRef,
                  {
                    status: "sending",
                    recipientUid: uid,
                    deviceId: deviceDoc.id,
                    leaseUntilMs: Date.now() + DELIVERY_LEASE_MS,
                    updatedAt: FieldValue.serverTimestamp(),
                  },
                  {merge: true},
                );

                return "claimed";
              },
            );

            if (claimResult === "sent") {
              console.log(
                `SOS ${emergencyId}: device ${deviceDoc.id} was already notified.`,
              );
              return;
            }

            if (claimResult === "busy") {
              // Do not mark a concurrent invocation as successful.
              // Throw so the event can be retried.
              throw new Error(
                `SOS ${emergencyId}: device ${deviceDoc.id} is being processed; retry later.`,
              );
            }

            try {
              await getMessaging().send({
                fid,
                notification: {
                  title: "SAFEFAMILY SOS ALERT",
                  body: `${senderName} has triggered an SOS. Open SAFEFAMILY for details.`,
                },
                data: {
                  type: "sos",
                  familyId,
                  alertId: emergencyId,
                  senderUid,
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "safefamily_sos_alerts",
                    sound: "default",
                    tag: emergencyId,
                  },
                },
              });

              await deliveryRef.set(
                {
                  status: "sent",
                  leaseUntilMs: 0,
                  sentAt: FieldValue.serverTimestamp(),
                  updatedAt: FieldValue.serverTimestamp(),
                },
                {merge: true},
              );

              console.log(
                `SOS ${emergencyId}: notification accepted for member ${uid}, device ${deviceDoc.id}.`,
              );
            } catch (error) {
              const errorCode = getErrorCode(error);

              // Remove a device only for the confirmed FID-specific error.
              if (
                errorCode === "messaging/installation-id-not-registered"
              ) {
                await deviceDoc.ref.delete();

                await deliveryRef.set(
                  {
                    status: "failed",
                    errorCode,
                    leaseUntilMs: 0,
                    updatedAt: FieldValue.serverTimestamp(),
                  },
                  {merge: true},
                );

                console.warn(
                  `Removed unregistered FID for member ${uid}, device ${deviceDoc.id}.`,
                );

                return;
              }

              // Preserve device records for transient and unknown failures.
              await deliveryRef.set(
                {
                  status: "failed",
                  errorCode: errorCode ?? "unknown",
                  leaseUntilMs: 0,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                {merge: true},
              );

              console.error(
                `SOS ${emergencyId}: send failed for member ${uid}, device ${deviceDoc.id}:`,
                error,
              );

              throw error;
            }
          }),
        );

        const failures = deviceResults.filter(
          (result) => result.status === "rejected",
        );

        if (failures.length > 0) {
          throw new Error(
            `SOS ${emergencyId}: ${failures.length} device notification(s) failed for member ${uid}.`,
          );
        }

        console.log(
          `SOS ${emergencyId}: processed ${validDevices.length} device(s) for member ${uid}.`,
        );
      }),
    );

    const memberFailures = memberResults.filter(
      (result) => result.status === "rejected",
    );

    if (memberFailures.length > 0) {
      console.error(
        `SOS ${emergencyId}: ${memberFailures.length} member(s) could not be processed. Retrying event.`,
      );

      throw new Error(
        `SOS ${emergencyId}: one or more member notifications failed.`,
      );
    }
  },
);
