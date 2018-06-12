import React from 'react'
import { getAccounts, getContract, getWeb3 } from '../utils';
import contractDefinition from '../../build/contracts/PVTSD.json'

export default class Web3Container extends React.Component {
  state = { web3: null, accounts: null, contract: null }

  async componentDidMount () {
    console.log('====> web 3 container was mounted')
    try {
      const web3 = await getWeb3()
      const accounts = await getAccounts(web3)
      const contract = await getContract(web3, contractDefinition)
      this.setState({ web3, accounts, contract })
    } catch (error) {
      // alert(`Failed to load web3, accounts, or contract. Check console for details.`)
      console.log(error)
    }
  }

  render () {
    const { web3, accounts, contract } = this.state
    return web3 && accounts
      ? this.props.render({ web3, accounts, contract })
      : this.props.renderLoading()
  }
}