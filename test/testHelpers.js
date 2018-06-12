module.exports.numFromWei = (bignumber, unit = "ether") => web3.fromWei(bignumber, unit).toNumber()
// We return the wei as a string because the toNumber calculation is inacurate past 15 decimal points.
module.exports.stringFromWei = (bignumber, unit = "ether") => web3.fromWei(bignumber, unit).toString()

module.exports.numToWei = (bignumber, unit = "ether") => web3.toWei(`${bignumber}`, unit)

module.exports.buyTokens = (eth, addr) => (
  {
    value: web3.toWei(eth, 'ether'),
    from: addr
  }
)

module.exports.equalsWithNormalizedRounding = (value1, value2) => {
  {
    const epsilon = 0.0000001;
    return (Math.abs(value1 - value2) < epsilon);
  }
}

module.exports.assertExpectedError = async (promise) => {
  try {
    await promise;
    fail('expected to fail')();
  } catch (error) {
    assert(error.message.indexOf('revert') >= 0, `Expected throw, but got: ${error.message}`);
  }
}
