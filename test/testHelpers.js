module.exports.numFromWei = (bignumber, unit = "ether") => web3.fromWei(bignumber, unit).toNumber()

module.exports.numToWei = (bignumber, unit = "ether") => web3.toWei(`${bignumber}`, unit)

module.exports.buyTokens = (eth, addr) => (
  {
    value: web3.toWei(eth, 'ether'),
    from: addr
  }
)

module.exports.assertExpectedError = async (promise) => {
  try {
    await promise;
    fail('expected to fail')();
  } catch (error) {
    assert(error.message.indexOf('revert') >= 0, `Expected throw, but got: ${error.message}`);
  }
}