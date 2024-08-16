const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("ForwarderModule", (m) => {
  const forwarder = m.contract("Forwarder");
  return { forwarder };
});
