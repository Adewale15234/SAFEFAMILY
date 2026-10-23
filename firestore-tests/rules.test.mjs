import fs from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const projectId = 'safefamily-app-aa07b';
const rules = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

let testEnv;
let passed = 0;
let failed = 0;

async function test(name, callback) {
  try {
    await callback();
    passed++;
    console.log(`PASS: ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL: ${name}`);
    console.error(error?.stack ?? error);
  }
}

async function seedFamily(familyId, ownerUid = 'owner-user') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'families', familyId), {
      ownerUid,
      familyName: 'Test Family',
      guardianName: 'Test Guardian',
      phone: '08000000000',
      city: 'Kaduna',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'families', familyId, 'members', ownerUid), {
      uid: ownerUid,
      role: 'owner',
      status: 'active',
      joinedAt: serverTimestamp(),
      displayName: 'Test Owner',
      email: 'owner@example.com',
      invitationId: '',
    });
    await setDoc(doc(db, 'users', ownerUid), {
      uid: ownerUid,
      familyId,
      role: 'owner',
      status: 'active',
      updatedAt: serverTimestamp(),
    });
  });
}

async function seedMember(familyId, memberUid, email) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, 'families', familyId, 'members', memberUid), {
      uid: memberUid,
      role: 'member',
      status: 'active',
      joinedAt: serverTimestamp(),
      displayName: 'Test Member',
      email,
      invitationId: 'test-invitation',
    });

    await setDoc(doc(db, 'users', memberUid), {
      uid: memberUid,
      familyId,
      role: 'member',
      status: 'active',
      updatedAt: serverTimestamp(),
    });
  });
}
async function main() {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });

  await testEnv.clearFirestore();

  await test('signed-in user can create a family and owner membership atomically', async () => {
    const db = testEnv.authenticatedContext('new-owner', {
      email: 'new-owner@example.com',
    }).firestore();

    const batch = writeBatch(db);
    const familyRef = doc(db, 'families', 'family-create-test');
    const memberRef = doc(db, 'families', 'family-create-test', 'members', 'new-owner');
    const userRef = doc(db, 'users', 'new-owner');

    batch.set(familyRef, {
      ownerUid: 'new-owner',
      familyName: 'New Family',
      guardianName: 'New Guardian',
      phone: '08000000001',
      city: 'Kaduna',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    batch.set(memberRef, {
      uid: 'new-owner',
      role: 'owner',
      status: 'active',
      joinedAt: serverTimestamp(),
      displayName: 'New Owner',
      email: 'new-owner@example.com',
      invitationId: '',
    });

    batch.set(userRef, {
      uid: 'new-owner',
      familyId: 'family-create-test',
      role: 'owner',
      status: 'active',
      updatedAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  await seedFamily('private-family');

  await test('active family owner can read the family profile', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    await assertSucceeds(getDoc(doc(db, 'families', 'private-family')));
  });

  await test('unrelated signed-in user cannot read a private family', async () => {
    const db = testEnv.authenticatedContext('unrelated-user').firestore();
    await assertFails(getDoc(doc(db, 'families', 'private-family')));
  });

  await test('account owner can read their own family index', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    const snapshot = await assertSucceeds(getDoc(doc(db, 'users', 'owner-user')));
    if (snapshot.data()?.familyId !== 'private-family') {
      throw new Error('Account index did not return the expected family ID.');
    }
  });

  await test('another account cannot read the owner family index', async () => {
    const db = testEnv.authenticatedContext('unrelated-user').firestore();
    await assertFails(getDoc(doc(db, 'users', 'owner-user')));
  });

  await test('account cannot create an index without matching membership', async () => {
    const db = testEnv.authenticatedContext('fake-member', {
      email: 'fake@example.com',
    }).firestore();

    await assertFails(setDoc(doc(db, 'users', 'fake-member'), {
      uid: 'fake-member',
      familyId: 'private-family',
      role: 'member',
      status: 'active',
      updatedAt: serverTimestamp(),
    }));
  });

  await test('account cannot overwrite an existing family index', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();

    await assertFails(setDoc(doc(db, 'users', 'owner-user'), {
      uid: 'owner-user',
      familyId: 'attacker-chosen-family',
      role: 'owner',
      status: 'active',
      updatedAt: serverTimestamp(),
    }));
  });

  await test('family owner can update allowed profile fields', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'families', 'private-family'), {
        familyName: 'Updated Test Family',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await test('non-owner cannot update the family profile', async () => {
    const db = testEnv.authenticatedContext('unrelated-user').firestore();
    await assertFails(
      updateDoc(doc(db, 'families', 'private-family'), {
        familyName: 'Unauthorized Change',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await test('unauthenticated user cannot read a family', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'families', 'private-family')));
  });

  await test('unapproved chat collection access is denied', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    await assertFails(
      setDoc(doc(db, 'families', 'private-family', 'messages', 'test-message'), {
        text: 'This should be denied',
      }),
    );
  });

  await test('owner can add a household person', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'families', 'private-family', 'people', 'person-1'), {
        name: 'Test Relative',
        relationship: 'Sibling',
        phone: '08000000002',
        age: 20,
        createdBy: 'owner-user',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await test('non-owner cannot add a household person', async () => {
    const db = testEnv.authenticatedContext('unrelated-user').firestore();
    await assertFails(
      setDoc(doc(db, 'families', 'private-family', 'people', 'person-2'), {
        name: 'Unauthorized Relative',
        relationship: 'Sibling',
        phone: '08000000003',
        age: 20,
        createdBy: 'unrelated-user',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await test('owner can create a pending invitation', async () => {
    const db = testEnv.authenticatedContext('owner-user').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'families', 'private-family', 'invitations', 'invite-1'), {
        invitedEmail: 'member@example.com',
        invitedBy: 'owner-user',
        status: 'pending',
        role: 'member',
        createdAt: serverTimestamp(),
        expiresAt: Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)),
        acceptedBy: '',
        acceptedAt: null,
      }),
    );
  });

  await test('non-owner cannot create an invitation', async () => {
    const db = testEnv.authenticatedContext('unrelated-user').firestore();
    await assertFails(
      setDoc(doc(db, 'families', 'private-family', 'invitations', 'invite-2'), {
        invitedEmail: 'someone@example.com',
        invitedBy: 'unrelated-user',
        status: 'pending',
        role: 'member',
        createdAt: serverTimestamp(),
        expiresAt: Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)),
        acceptedBy: '',
        acceptedAt: null,
      }),
    );
  });

  await test('account with the wrong email cannot accept an invitation', async () => {
    const db = testEnv.authenticatedContext('wrong-user', {
      email: 'wrong@example.com',
    }).firestore();

    await assertFails(
      updateDoc(doc(db, 'families', 'private-family', 'invitations', 'invite-1'), {
        status: 'accepted',
        acceptedBy: 'wrong-user',
        acceptedAt: serverTimestamp(),
      }),
    );
  });
  await test('intended invited account can accept and join atomically', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-user').firestore();
    const invitationRef = doc(
      ownerDb,
      'families',
      'private-family',
      'invitations',
      'invite-accept-success',
    );

    await assertSucceeds(
      setDoc(invitationRef, {
        invitedEmail: 'joining-member@example.com',
        invitedBy: 'owner-user',
        status: 'pending',
        role: 'member',
        createdAt: serverTimestamp(),
        expiresAt: Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)),
        acceptedBy: '',
        acceptedAt: null,
      }),
    );

    const memberUid = 'joining-member';
    const memberDb = testEnv.authenticatedContext(memberUid, {
      email: 'joining-member@example.com',
    }).firestore();

    const batch = writeBatch(memberDb);

    batch.update(
      doc(
        memberDb,
        'families',
        'private-family',
        'invitations',
        'invite-accept-success',
      ),
      {
        status: 'accepted',
        acceptedBy: memberUid,
        acceptedAt: serverTimestamp(),
      },
    );

    batch.set(
      doc(memberDb, 'families', 'private-family', 'members', memberUid),
      {
        uid: memberUid,
        role: 'member',
        status: 'active',
        joinedAt: serverTimestamp(),
        displayName: 'Joining Member',
        email: 'joining-member@example.com',
        invitationId: 'invite-accept-success',
      },
    );

    batch.set(doc(memberDb, 'users', memberUid), {
      uid: memberUid,
      familyId: 'private-family',
      role: 'member',
      status: 'active',
      updatedAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());

    await assertSucceeds(
      getDoc(doc(memberDb, 'families', 'private-family')),
    );
  });
  // GPS LOCATION SECURITY TESTS
  await seedFamily('location-family', 'location-owner');
  await seedMember(
    'location-family',
    'location-member',
    'location-member@example.com',
  );
  await seedFamily('other-location-family', 'other-location-owner');

  // Seed a location in a separate family for the isolation test.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'families',
        'other-location-family',
        'locations',
        'other-location-owner',
      ),
      {
        uid: 'other-location-owner',
        latitude: 10,
        longitude: 7,
        accuracy: 10,
        updatedAt: serverTimestamp(),
        sharingEnabled: true,
      },
    );
  });

  await test(
    'family owner can publish their own valid GPS location',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertSucceeds(
        setDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-owner'),
          {
            uid: 'location-owner',
            latitude: 9.0579,
            longitude: 7.4951,
            accuracy: 12,
            updatedAt: serverTimestamp(),
            sharingEnabled: true,
          },
        ),
      );
    },
  );

  await test(
    'active family member can read a location in their own family',
    async () => {
      const db = testEnv.authenticatedContext('location-member', {
        email: 'location-member@example.com',
      }).firestore();

      await assertSucceeds(
        getDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-owner'),
        ),
      );
    },
  );

  await test(
    'member cannot publish a location under another UID',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertFails(
        setDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-member'),
          {
            uid: 'location-owner',
            latitude: 9,
            longitude: 7,
            accuracy: 10,
            updatedAt: serverTimestamp(),
            sharingEnabled: true,
          },
        ),
      );
    },
  );

  await test(
    'active member cannot read a different family location',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertFails(
        getDoc(
          doc(
            db,
            'families',
            'other-location-family',
            'locations',
            'other-location-owner',
          ),
        ),
      );
    },
  );

  await test(
    'GPS location with out-of-range coordinates is rejected',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertFails(
        setDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-owner'),
          {
            uid: 'location-owner',
            latitude: 91,
            longitude: 7,
            accuracy: 10,
            updatedAt: serverTimestamp(),
            sharingEnabled: true,
          },
        ),
      );
    },
  );

  await test(
    'GPS location with unexpected fields is rejected',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertFails(
        setDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-owner'),
          {
            uid: 'location-owner',
            latitude: 9,
            longitude: 7,
            accuracy: 10,
            updatedAt: serverTimestamp(),
            sharingEnabled: true,
            secret: 'unexpected',
          },
        ),
      );
    },
  );

  await test(
    'member can delete their own location to stop sharing',
    async () => {
      const db = testEnv.authenticatedContext('location-owner').firestore();

      await assertSucceeds(
        (await import('firebase/firestore')).deleteDoc(
          doc(db, 'families', 'location-family', 'locations', 'location-owner'),
        ),
      );
    },
  );
    // EMERGENCY SOS SECURITY TESTS
  await seedFamily('emergency-family', 'emergency-owner');
  await seedMember(
    'emergency-family',
    'emergency-member',
    'emergency-member@example.com',
  );
  await seedFamily('other-emergency-family', 'other-emergency-owner');

  function emergencyPayload(createdBy, overrides = {}) {
    return {
      createdBy,
      senderName: 'Test Sender',
      status: 'active',
      createdAt: serverTimestamp(),
      latitude: null,
      longitude: null,
      accuracy: null,
      locationUpdatedAt: null,
      message: 'I need help.',
      ...overrides,
    };
  }

  await test('active family owner can create a valid SOS alert', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertSucceeds(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
        emergencyPayload('emergency-owner'),
      ),
    );
  });

  await test('active family member can read an emergency in their family', async () => {
    const db = testEnv.authenticatedContext('emergency-member').firestore();

    await assertSucceeds(
      getDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });

  await test('unrelated user cannot read a family SOS alert', async () => {
    const db = testEnv.authenticatedContext('other-emergency-owner').firestore();

    await assertFails(
      getDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });

  await test('SOS sender cannot impersonate another family member', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-spoof-1'),
        emergencyPayload('emergency-member'),
      ),
    );
  });

  await test('SOS with invalid coordinates is rejected', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-invalid-1'),
        emergencyPayload('emergency-owner', {
          latitude: 95,
          longitude: 7,
          accuracy: 10,
          locationUpdatedAt: Timestamp.now(),
        }),
      ),
    );
  });

  await test('unauthenticated user cannot create an SOS alert', async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-anonymous-1'),
        emergencyPayload('emergency-owner'),
      ),
    );
  });

  await test('SOS documents cannot be deleted by family members', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      (await import('firebase/firestore')).deleteDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });
await testEnv.cleanup();

  console.log(`\nResults: ${passed} passed, ${failed} failed.`);
  if (failed > 0) process.exitCode = 1;
}

main().catch(async (error) => {
  console.error(error);
  if (testEnv)   // EMERGENCY SOS SECURITY TESTS
  await seedFamily('emergency-family', 'emergency-owner');
  await seedMember(
    'emergency-family',
    'emergency-member',
    'emergency-member@example.com',
  );
  await seedFamily('other-emergency-family', 'other-emergency-owner');

  function emergencyPayload(createdBy, overrides = {}) {
    return {
      createdBy,
      senderName: 'Test Sender',
      status: 'active',
      createdAt: serverTimestamp(),
      latitude: null,
      longitude: null,
      accuracy: null,
      locationUpdatedAt: null,
      message: 'I need help.',
      ...overrides,
    };
  }

  await test('active family owner can create a valid SOS alert', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertSucceeds(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
        emergencyPayload('emergency-owner'),
      ),
    );
  });

  await test('active family member can read an emergency in their family', async () => {
    const db = testEnv.authenticatedContext('emergency-member').firestore();

    await assertSucceeds(
      getDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });

  await test('unrelated user cannot read a family SOS alert', async () => {
    const db = testEnv.authenticatedContext('other-emergency-owner').firestore();

    await assertFails(
      getDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });

  await test('SOS sender cannot impersonate another family member', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-spoof-1'),
        emergencyPayload('emergency-member'),
      ),
    );
  });

  await test('SOS with invalid coordinates is rejected', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-invalid-1'),
        emergencyPayload('emergency-owner', {
          latitude: 95,
          longitude: 7,
          accuracy: 10,
          locationUpdatedAt: Timestamp.now(),
        }),
      ),
    );
  });

  await test('unauthenticated user cannot create an SOS alert', async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(
      setDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-anonymous-1'),
        emergencyPayload('emergency-owner'),
      ),
    );
  });

  await test('SOS documents cannot be deleted by family members', async () => {
    const db = testEnv.authenticatedContext('emergency-owner').firestore();

    await assertFails(
      (await import('firebase/firestore')).deleteDoc(
        doc(db, 'families', 'emergency-family', 'emergencies', 'sos-owner-1'),
      ),
    );
  });
await testEnv.cleanup();
  process.exitCode = 1;
});
