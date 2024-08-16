const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("FileverseZuPassRegistryModule", (m) => {
  const trustedForwarder = m.getParameter("trustedForwarder");
  const registry = m.contract("FileverseZuPassRegistry", [trustedForwarder]);
  return { registry };
});
