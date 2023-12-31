import * as path from "node:path";
import * as fs from "node:fs";
import { server, configServer, configServerDefault } from "./server";
import type { ServerConfigType } from "./server";

class SslDev {
  constructor(private configServer: ServerConfigType) {
    this.configServer = configServer;
    return this;
  }

  configure(configServer: ServerConfigType) {
    const currenConfig = this.configServer;
    this.configServer = {
      ...currenConfig,
      ...configServer,
    };
    return this;
  }

  run() {
    const { rootApp, keysPath, publicDomain, webPort } = this.configServer;
    const sslFiles: { key: string; cert: string } = {
      key: path.resolve(`${rootApp}`, `${keysPath}`, `${publicDomain}.key.pem`),
      cert: path.resolve(
        `${rootApp}`,
        `${keysPath}`,
        `${publicDomain}.cert.pem`,
      ),
    };

    Object.entries(sslFiles).map((file) => {
      if (!fs.existsSync(file[1])) {
        const reason = `\nfile not found!\n${file[0]}: ${file[1]}`;
        throw new Error(reason);
      }
    });

    const options = {
      key: fs.readFileSync(sslFiles.key),
      cert: fs.readFileSync(sslFiles.cert),
    };

    const bootstrap = server(options, this.configServer);
    bootstrap.listen(webPort, () => {
      console.log(`Running at https://${publicDomain}:${webPort}`);
    });
  }
}

const sslldev = new SslDev(configServerDefault);
export { sslldev, configServer };
