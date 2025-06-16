#!/usr/bin/env node

// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import * as azdev from "azure-devops-node-api";

import { AccessToken, DefaultAzureCredential } from "@azure/identity";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { configureAllTools } from "./tools.js";
import { configurePrompts } from "./prompts.js";
import cors from "cors";
import express from "express";
import { packageVersion } from "./version.js";
import { userAgent } from "./utils.js";

// Get organization name from environment variable
const orgName = process.env.AZURE_ORGANIZATION_NAME;
if (!orgName) {
  console.error("Error: AZURE_ORGANIZATION_NAME environment variable is required");
  process.exit(1);
}

const orgUrl = "https://dev.azure.com/" + orgName;
const port = process.env.PORT || 3000;

async function getAzureDevOpsToken(): Promise<AccessToken> {
  process.env.AZURE_TOKEN_CREDENTIALS = "dev";
  const credential = new DefaultAzureCredential(); // CodeQL [SM05138] resolved by explicitly setting AZURE_TOKEN_CREDENTIALS
  const token = await credential.getToken("499b84ac-1321-427f-aa17-267ca6975798/.default");
  return token;
}

async function getAzureDevOpsClient(): Promise<azdev.WebApi> {
  const token = await getAzureDevOpsToken();
  const authHandler = azdev.getBearerHandler(token.token);
  const connection = new azdev.WebApi(orgUrl, authHandler, undefined, {
    productName: "AzureDevOps.MCP",
    productVersion: packageVersion,
    userAgent: userAgent
  });
  return connection;
}

async function main() {
  const app = express();

  // Enable CORS for all routes
  app.use(cors({
    origin: true,
    credentials: true
  }));

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({
      status: 'healthy',
      version: packageVersion,
      organization: orgName,
      timestamp: new Date().toISOString()
    });
  });

  // Root endpoint with info
  app.get('/', (req, res) => {
    res.json({
      name: "Azure DevOps MCP Server",
      version: packageVersion,
      organization: orgName,
      description: "MCP server for interacting with Azure DevOps",
      endpoints: {
        health: "/health",
        mcp: "/sse"
      }
    });
  });

  // Create MCP server
  const server = new McpServer({
    name: "Azure DevOps MCP Server",
    version: packageVersion,
  });

  configurePrompts(server);

  configureAllTools(
    server,
    getAzureDevOpsToken,
    getAzureDevOpsClient
  );
  // SSE endpoint for MCP
  app.get("/sse", async (req, res) => {
    const transport = new SSEServerTransport("/sse", res);
    await server.connect(transport);
    await transport.start();
  });

  app.post("/sse", express.json(), async (req, res) => {
    // This would need session management for multiple clients
    // For now, this is a simplified implementation
    res.status(200).json({ status: "Message received" });
  });

  app.listen(port, () => {
    console.log(`Azure DevOps MCP Server version: ${packageVersion}`);
    console.log(`Server running on port ${port}`);
    console.log(`Organization: ${orgName}`);
    console.log(`Health check: http://localhost:${port}/health`);
    console.log(`MCP endpoint: http://localhost:${port}/sse`);
  });
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});

export { orgName };
