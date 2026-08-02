const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const { createApp } = require('../src/index.js');

function createStubFirestore() {
    return {
        collection(name) {
            if (name === 'fcm_outbox') {
                return {
                    where() {
                        return {
                            count() {
                                return {
                                    get() {
                                        return Promise.resolve({
                                            data: () => ({ count: 0 }),
                                        });
                                    },
                                };
                            },
                        };
                    },
                };
            }

            if (name === 'fcm_metrics') {
                return {
                    doc() {
                        return {
                            get() {
                                return Promise.resolve({ exists: false, data: () => ({}) });
                            },
                        };
                    },
                };
            }

            return {};
        },
    };
}

function startServer() {
    const app = createApp({ firestore: createStubFirestore() });
    return new Promise((resolve) => {
        const server = app.listen(0, () => {
            const address = server.address();
            resolve({
                server,
                baseUrl: `http://127.0.0.1:${address.port}`,
            });
        });
    });
}

test('health endpoint reports a healthy relay service', async () => {
    const { server, baseUrl } = await startServer();
    try {
        const response = await fetch(`${baseUrl}/health`);
        const body = await response.json();
        assert.equal(response.status, 200);
        assert.equal(body.ok, true);
        assert.equal(body.service, 'attendance-fcm-relay');
    } finally {
        server.close();
    }
});

test('status endpoint exposes request-id and telemetry payloads', async () => {
    const { server, baseUrl } = await startServer();
    try {
        const response = await fetch(`${baseUrl}/status`, {
            headers: { 'x-request-id': 'req-123' },
        });
        const body = await response.json();
        assert.equal(response.status, 200);
        assert.equal(body.ok, true);
        assert.equal(body.requestId, 'req-123');
        assert.ok(body.metrics);
    } finally {
        server.close();
    }
});
