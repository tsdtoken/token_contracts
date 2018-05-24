const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const moment = require('moment');

contract('PVTSDMock', (accounts) => {
  let pvtsdInstance;
  const numberOfMillisecsPerYear = 365 * 24 * 60 * 60 * 1000;
  const startTime = moment('2018-06-01 00:00:00', 'YYYY-MM-DD HH:mm:ss').unix();
  const currentTime = moment().unix();
  const endTime = moment('2018-07-01 00:00:00', 'YYYY-MM-DD HH:mm:ss').unix();
  const tokensReleaseDate = startTime + numberOfMillisecsPerYear;
  const exchangeRate = new web3.BigNumber(1);
  const owner = accounts[0];
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];

  beforeEach('setup contract for each test', async () => {
    pvtsdInstance = await PVTSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses
    );
  });

  it('has an owner', async () => {
    assert.equal(await pvtsdInstance.owner(), owner);
  });

  it('has an fundsWallet', async () => {
    assert.equal(await pvtsdInstance.fundsWallet(), owner);
  });

  it('has a valid start time', async () => {
    assert.equal(moment.unix(startTime).isValid(), true);
  });

  it('has a valid end time', async () => {
    assert.equal(moment.unix(endTime).isValid(), true);
  });
});
