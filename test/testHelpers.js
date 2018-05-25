module.exports.numFromWei = (bignumber) => web3.fromWei(bignumber, "ether").toNumber()

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