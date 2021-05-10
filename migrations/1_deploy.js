const Token = artifacts.require('Token');
const Lottery = artifacts.require('Lottery');

module.exports = function (deployer) {
  deployer.deploy(Token, "Test", "TEST", 18).then(function () {
    return deployer.deploy(Lottery);
  });
};
//, Token.address