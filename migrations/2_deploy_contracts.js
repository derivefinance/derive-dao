const DRV = artifacts.require("ERC20DRV"); 

module.exports = async function(deployer) {
  await deployer.deploy(DRV)
}