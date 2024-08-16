const hre = require("hardhat");
const ForwarderModule = require("../ignition/modules/Forwarder");
const FileverseZuPassRegistryModule = require("../ignition/modules/FileverseZuPassRegistry");

async function main() {
  const { forwarder } = await hre.ignition.deploy(ForwarderModule);
  const forwarderAddress = await forwarder.getAddress();
  console.log("Deployed Forwarder Address: ", forwarderAddress);
  const { registry } = await hre.ignition.deploy(
    FileverseZuPassRegistryModule,
    {
      parameters: {
        FileverseZuPassRegistryModule: { trustedForwarder: forwarderAddress },
      },
    }
  );
  console.log(`Registry deployed to: ${await registry.getAddress()}`);
}

main().catch(console.error);
