import https, { RequestOptions } from "node:https";
import handler from "serve-handler";
import { CustomConfig } from "@bicalho/custom-config";
import path from "node:path";

const rootAppDefault = path.resolve(__dirname, ".");
const configDefault = {
  rootApp: rootAppDefault,
  publicDomain: "localhost",
  contenPublic: "example",
  webPort: 8081,
  keysPath: "ssl",
  renderSingle: false,
  cleanUrls: ["/**"],
  rewrites: [{ source: "app/**", destination: "/index.html" }],
};

export const configServer = new CustomConfig();
configServer.configure(configDefault);

export type ServerConfigType = Partial<typeof configDefault>;
export const configServerDefault: ServerConfigType = configServer.getConfig();

export const server = (options: RequestOptions, config: ServerConfigType) =>
  https.createServer(options, (request, response) => {
    // You pass two more arguments for config and middleware
    // More details here: https://github.com/vercel/serve-handler#options
    const { renderSingle, cleanUrls, contenPublic, rewrites } = config;
    return handler(request, response, {
      renderSingle: renderSingle,
      cleanUrls: cleanUrls,
      public: contenPublic,
      rewrites: rewrites,
      headers: [
        {
          source: "**/*.@(jpg|jpeg|gif|png)",
          headers: [
            {
              key: "Cache-Control",
              value: "max-age=7200",
            },
          ],
        },
      ],
    });
  });
