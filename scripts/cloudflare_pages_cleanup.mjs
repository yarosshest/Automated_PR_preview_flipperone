import { execFileSync } from "node:child_process";

const projectName = process.env.CF_PAGES_PROJECT_NAME;
const previewBranch = process.env.CF_PAGES_PREVIEW_BRANCH;

if (!projectName) {
  throw new Error("CF_PAGES_PROJECT_NAME is required");
}

if (!previewBranch) {
  throw new Error("CF_PAGES_PREVIEW_BRANCH is required");
}

const branchAlias = `${previewBranch}.${projectName}.pages.dev`;

const raw = execFileSync(
  "wrangler",
  ["pages", "deployment", "list", "--project-name", projectName, "--json"],
  { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
);

const deployments = JSON.parse(raw);

const matches = deployments.filter((deployment) => {
  if (Array.isArray(deployment.aliases) && deployment.aliases.includes(branchAlias)) {
    return true;
  }

  if (deployment.deployment_trigger?.metadata?.branch === previewBranch) {
    return true;
  }

  if (deployment.url && deployment.url.includes(`${previewBranch}.`)) {
    return true;
  }

  return false;
});

if (matches.length === 0) {
  console.log(`No Pages deployments found for branch ${previewBranch}`);
  process.exit(0);
}

for (const deployment of matches) {
  if (!deployment.id) {
    continue;
  }

  console.log(`Deleting Pages deployment ${deployment.id}`);

  execFileSync(
    "wrangler",
    [
      "pages",
      "deployment",
      "delete",
      deployment.id,
      "--project-name",
      projectName,
    ],
    {
      stdio: ["pipe", "inherit", "inherit"],
      input: "y\n",
    },
  );
}
