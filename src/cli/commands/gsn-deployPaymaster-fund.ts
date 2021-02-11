import { ether } from '@openzeppelin/test-helpers'
import CommandsLogic from '../CommandsLogic'
import { configureGSN } from '../../relayclient/GSNConfigurator'
import { getMnemonic, getNetworkUrl, getDeployPaymasterAddress, getRelayHubAddress, gsnCommander } from '../utils'

const commander = gsnCommander(['n', 'f', 'h', 'm'])
  .option('--paymaster <address>',
    'address of the deploy paymaster contract (defaults to address from build/gsn/DeployPaymaster.json if exists)')
  .option('--amount <amount>', 'amount of funds to deposit for the paymaster contract, in wei (defaults to 0.01 RBTC)')
  .parse(process.argv);

(async () => {
  const network: string = commander.network
  const nodeURL = getNetworkUrl(network)

  const hub = getRelayHubAddress(commander.hub)
  const paymaster = getDeployPaymasterAddress(commander.paymaster)

  if (hub == null || paymaster == null) {
    // eslint-disable-next-line @typescript-eslint/restrict-template-expressions
    throw new Error(`Contracts not found: hub: ${hub} paymaster: ${paymaster} `)
  }

  const mnemonic = getMnemonic(commander.mnemonic)
  const logic = new CommandsLogic(nodeURL, configureGSN({ relayHubAddress: hub }), mnemonic)
  const from = commander.from ?? await logic.findWealthyAccount()
  const amount = commander.amount ?? ether('0.01')

  const balance = await logic.fundPaymaster(from, paymaster, amount)
  console.log(`Paymaster ${paymaster} balance is now ${balance.toString()} wei`)
})().catch(
  reason => {
    console.error(reason)
    process.exit(1)
  }
)
