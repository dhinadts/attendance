const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const APP_ROOT_COLLECTION =
  process.env.FIRESTORE_APP_ROOT_COLLECTION || "Attendance";
const APP_ROOT_DOCUMENT = process.env.FIRESTORE_APP_ROOT_DOCUMENT || "main";
const PASSWORD = "Qwerty@123";

function loadDotEnv() {
  const envPath = path.join(__dirname, "..", ".env");
  if (!fs.existsSync(envPath)) return;

  const text = fs.readFileSync(envPath, "utf8");

  const multilineServiceAccount = text.match(
    /(?:^|\r?\n)FIREBASE_SERVICE_ACCOUNT_JSON=([\s\S]*?)(?=\r?\n[A-Z0-9_]+=|\s*$)/,
  );
  if (
    multilineServiceAccount &&
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON === undefined
  ) {
    const rawAccount = multilineServiceAccount[1].trim();
    const endIndex = rawAccount.lastIndexOf("}");
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON =
      endIndex >= 0 ? rawAccount.slice(0, endIndex + 1) : rawAccount;
  }

  const lines = text.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) {
      continue;
    }
    const index = trimmed.indexOf("=");
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim();
    if (
      key &&
      key !== "FIREBASE_SERVICE_ACCOUNT_JSON" &&
      process.env[key] === undefined
    ) {
      process.env[key] = value;
    }
  }
}

function parseServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64
    ? Buffer.from(
        process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
        "base64",
      ).toString("utf8")
    : process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (!raw) return null;

  const account = JSON.parse(raw);
  if (typeof account.private_key === "string") {
    account.private_key = account.private_key.replace(/\\n/g, "\n");
  }
  return account;
}

function initializeFirebase() {
  if (admin.apps.length > 0) return;

  const serviceAccount = parseServiceAccount();
  const projectId = process.env.FIREBASE_PROJECT_ID || serviceAccount?.project_id;

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

function appCollection(firestore, collectionName) {
  return firestore
    .collection(APP_ROOT_COLLECTION)
    .doc(APP_ROOT_DOCUMENT)
    .collection(collectionName);
}

function profileName(user) {
  return `${user.firstName} ${user.lastName}`.trim();
}

const teams = ["TECH", "OPERATIONS", "SALES", "ANALYST", "MARKETING"];

const teamRoles = {
  TECH: "SENIOR SOFTWARE DEVELOPER",
  OPERATIONS: "EXECUTIVE",
  SALES: "RELATIONSHIP MANAGER",
  ANALYST: "DEVELOPER",
  MARKETING: "TESTER",
};

const baseUsers = [
  {
    employeeId: "DTS0001",
    email: "ceo@gmail.com",
    firstName: "Demo",
    lastName: "CEO",
    team: "CEO",
    appRole: "admin",
    organizationRole: "CEO",
    employeeRole: "CEO",
    canApproveLeave: true,
    canManageSalary: true,
  },
  {
    employeeId: "DTS0002",
    email: "director@gmail.com",
    firstName: "Demo",
    lastName: "Director",
    team: "DIRECTOR",
    appRole: "admin",
    organizationRole: "DIRECTOR",
    employeeRole: "DIRECTOR",
    canApproveLeave: true,
    canManageSalary: true,
  },
];

const generatedUsers = teams.flatMap((team, teamIndex) =>
  Array.from({ length: 3 }, (_, i) => {
    const n = teamIndex * 3 + i + 1;
    return {
      employeeId: `DTS${String(n + 2).padStart(4, "0")}`,
      email: `demo.${team.toLowerCase()}.${i + 1}@gmail.com`,
      firstName: "Demo",
      lastName: `${team}${i + 1}`,
      team,
      appRole: "employee",
      organizationRole: "EMPLOYEE",
      employeeRole: teamRoles[team] || "EMPLOYEE",
      canApproveLeave: false,
      canManageSalary: false,
    };
  }),
);

const demoUsers = [...baseUsers, ...generatedUsers];

async function upsertAuthUser(user) {
  try {
    const existing = await admin.auth().getUserByEmail(user.email);
    await admin.auth().updateUser(existing.uid, {
      password: PASSWORD,
      displayName: profileName(user),
      disabled: false,
      emailVerified: true,
    });
    return existing.uid;
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;

    const created = await admin.auth().createUser({
      email: user.email,
      password: PASSWORD,
      displayName: profileName(user),
      emailVerified: true,
      disabled: false,
    });
    return created.uid;
  }
}

async function upsertFirestoreUser(firestore, user, uid) {
  const displayName = profileName(user);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const userDoc = {
    uid,
    email: user.email,
    role: user.appRole,
    employeeId: user.employeeId,
    firstName: user.firstName,
    lastName: user.lastName,
    nickName: user.firstName,
    displayName,
    department: user.team,
    teamId: user.team,
    employeeRole: user.employeeRole,
    organizationRole: user.organizationRole,
    accessRoleName: user.organizationRole,
    canApproveLeave: user.canApproveLeave,
    canManageSalary: user.canManageSalary,
    permissions: {
      approveLeave: user.canApproveLeave,
      manageSalary: user.canManageSalary,
    },
    active: true,
    companyCode: "DTS",
    updatedAt: now,
    createdAt: now,
  };

  const profileDoc = {
    employeeId: user.employeeId,
    uid,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    nickName: user.firstName,
    employeeName: displayName,
    department: user.team,
    teamId: user.team,
    role: user.employeeRole,
    employeeRole: user.employeeRole,
    designation: user.employeeRole,
    organizationRole: user.organizationRole,
    accessRoleName: user.organizationRole,
    status: "active",
    companyCode: "DTS",
    updatedAt: now,
    createdAt: now,
  };

  await appCollection(firestore, "users").doc(uid).set(userDoc, {
    merge: true,
  });

  await appCollection(firestore, "employee_profiles")
    .doc(user.employeeId)
    .set(profileDoc, { merge: true });

  await appCollection(firestore, "teams").doc(user.team).set(
    {
      teamId: user.team,
      name: user.team,
      active: true,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true },
  );
}

async function main() {
  loadDotEnv();
  initializeFirebase();

  const firestore = admin.firestore();
  const created = [];

  for (const user of demoUsers) {
    const uid = await upsertAuthUser(user);
    await upsertFirestoreUser(firestore, user, uid);
    created.push({
      employeeId: user.employeeId,
      email: user.email,
      team: user.team,
      appRole: user.appRole,
      organizationRole: user.organizationRole,
      employeeRole: user.employeeRole,
    });
  }

  console.log(JSON.stringify({ ok: true, users: created }, null, 2));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});