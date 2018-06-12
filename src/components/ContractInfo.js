import React, { Component } from 'react';
import { promisify } from '../utils';
import { ContractInfoNoMeta, Web3Container, NoMetaMask } from './'

// Component is already destructured
class ContractInfo extends Component {
  state = {
    balance: undefined,
    totalEthRaised: 0,
    tokensRemaining: 0,
    totalSupply: 0,
    minPurchase: 0,
    walletAddress: undefined,
    isWhiteListed: false,
    exchangeRate: 0
  }

  componentDidMount() {
    this.getTotalAmountRaised();
    this.getTokensRemaining();
    this.getWalletInfo();
    this.listenToEvents();
    this.getExchangeRate();
    this.getTotalSupplyAndMinPurchase();
  }

  getExchangeRate = async () => {
    const { contract, web3 } = this.props
    try {
      const exchangeRate = await contract.exchangeRate.call();
      const rateInEther = web3.fromWei(exchangeRate / 1, 'ether');
      this.setState({ exchangeRate: rateInEther });
    } catch (error) {
      console.log('Something went wrong in get exchange rate: ', error);
    }
  }

  getTotalAmountRaised = async () => {
    const { contract, web3 } = this.props
    try {
      const result = await contract.totalEthRaised.call()
      const totalEthRaised = web3.fromWei(result.toString(), 'ether')
      this.setState({ totalEthRaised })
    } catch (error) {
      console.log('Something went wrong in get total amount raised: ', error)
    }
  }

  getTokensRemaining = async () => {
    const { contract, web3 } = this.props;
    try {
      const fundsWallet = await contract.pvtFundsWallet.call();
      const fundsWalletBalance = await contract.balanceOf(fundsWallet);
      const tokensRemaining = Math.round(fundsWalletBalance / 10e17);
      const tokensSold = 55000000 - tokensRemaining;
      this.setState({ tokensRemaining, tokensSold });
    } catch (error) {
      console.log('Something went wrong in get tokens remaining: ', error);
    }
  }

  getTotalSupplyAndMinPurchase = async () => {
    const { contract, web3 } = this.props;
    try {
      let totalSupply = await contract.totalSupply.call();
      const minPurchase = await contract.minPurchase.call();
      totalSupply = web3.fromWei(totalSupply.toString(), 'ether');
      minPurchase = web3.fromWei(minPurchase.toString(), 'ether');
      this.setState({ totalSupply, minPurchase });
    } catch (error) {
      console.log('Something went wrong in getting total supply and min purchase: ', error);
    }
  }

  getWalletInfo = async () => {
    let walletBal;
    const { accounts, web3 } = this.props;
    web3.eth.getBalance(accounts[0], (err, balance) => {
      this.setState({ balance: web3.fromWei(balance.toString(), 'ether')});
    })
    this.setState({ walletAddress: accounts[0], balance: walletBal });
  }

  isAddressWhiteListed = async (address) => {
    const { contract } = this.props;
    try {
      const isWhiteListed = await contract.isWhiteListed(address);
      this.setState({ isWhiteListed });
    } catch (error) {
      console.log('Something went wrong checking the white list', error)
    }
  }

  listenToEvents = async () => {
    try {
      this.props.contract.Transfer({}, {
        fromBlock: 'latest',
      }).watch((error, event) => {
        this.getTotalAmountRaised();
        this.getTokensRemaining();
      });
    } catch (error) {
      console.log('Something went wrong in listen to events: ', error);
    };

    try {
      this.props.contract.ExchangeRateUpdated({}, {
        fromBlock: 'latest',
      }).watch((error, event) => {
        this.getExchangeRate();
      });
    } catch (error) {
      console.log('Something went wrong in listen to events: ', error);
    };
  }

  render() {
    const { 
      balance, 
      tokensRemaining, 
      tokensSold, 
      totalEthRaised, 
      walletAddress, 
      exchangeRate, 
      isWhiteListed,
      totalSupply,
      minPurchase
    } = this.state;

    return (
      <div>
        <h1>Private TSD</h1>
        <p>---------</p>
        <p>Your wallet address: {walletAddress}</p>
        <p>Your wallet balance: {balance} ether</p>
        <p>Is white listed: {`${isWhiteListed}`}</p>
        <p>---------</p>
        <p>Total supply: {totalSupply} PVTSD</p>
        <p>Total tokens remaining: {tokensRemaining} PVTSD</p>
        <p>Minimun purchase: {minPurchase} ether</p>
        <p>Total ether raised: {totalEthRaised} ether</p>
        <p>Total PVTSD sold: {tokensSold}</p>
        <p>Current exchange rate: 1 PVTSD = {exchangeRate} ether</p>
      </div>
    )
  }
}

export const Web3ContractInfo = () => (
  <Web3Container
    renderLoading={() => <NoMetaMask />}
    render={({ accounts, contract, web3 }) => (
        <ContractInfo accounts={accounts} contract={contract} web3={web3} />
    )}
  />
)