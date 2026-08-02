const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

(async () => {
    const projectId = 'attendance-rules-test';
    // Resolve to repository root firestore.rules
    const rulesPath = path.join(__dirname, '..', '..', '..', 'firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    const env = await initializeTestEnvironment({
        projectId,
        firestore: { rules },
    });

    try {
        // Seed user documents without security rules
        await env.withSecurityRulesDisabled(async (context) => {
            const db = context.firestore();
            await db.collection('users').doc('employee-1').set({ role: 'employee', employeeId: 'EMP1', teamId: 'TEAM1' });
            await db.collection('users').doc('admin-1').set({ role: 'admin', employeeId: 'ADMIN1', teamId: 'TEAM1' });
        });

        const aliceDb = env.authenticatedContext('employee-1').firestore();
        const adminDb = env.authenticatedContext('admin-1').firestore();

        // Employee should NOT be able to create a leave request that sets server fields
        await assertFails(aliceDb.collection('leave_requests').doc('leave1').set({
            employeeId: 'EMP1',
            date: '2026-08-03',
            status: 'approved',
            createdAt: new Date().toISOString(),
        }));

        // Employee can create a normal leave request
        await assertSucceeds(aliceDb.collection('leave_requests').doc('leave2').set({
            employeeId: 'EMP1',
            date: '2026-08-03',
            status: 'requested_leave'
        }));

        // Admin may set server fields
        await assertSucceeds(adminDb.collection('leave_requests').doc('leave3').set({
            employeeId: 'ADMIN1',
            date: '2026-08-03',
            status: 'approved',
            createdAt: new Date().toISOString()
        }));

        // Employee should NOT be able to create outbox messages with status set
        await assertFails(aliceDb.collection('fcm_outbox').doc('m1').set({
            senderUid: 'employee-1',
            title: 'hello',
            body: 'world',
            status: 'sent'
        }));

        // Employee can create minimal outbox message
        await assertSucceeds(aliceDb.collection('fcm_outbox').doc('m2').set({
            senderUid: 'employee-1',
            title: 'hello',
            body: 'world'
        }));

        console.log('FIRESTORE RULES TESTS: ALL OK');
        await env.cleanup();
        process.exit(0);
    } catch (err) {
        console.error('FIRESTORE RULES TESTS: FAILED', err);
        await env.cleanup();
        process.exit(1);
    }
})();
