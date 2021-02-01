import { createStore } from './redux_helpers.js'

import $ from 'jquery'
import Analytics from 'analytics'
import segmentPlugin from '@analytics/segment'
import omit from 'lodash/omit'
import uniqid from 'uniqid'

let analytics
let store

const initialState = {
  userID: localStorage.getItem('userID')
}

function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'SET_USER_ID': {
      const id = uniqid()
      localStorage.setItem('userID', id)
      return Object.assign({}, state, { userID: id })
    }
    default:
      return state
  }
}

// return string representation of web page path
function getPageName (path) {
  switch (true) {
    case path.includes('/search'):
      return '404SearchResult'
    case path === '/':
      return 'home'
    case path === '/txs':
      return 'validatedTransactions'
    case path === '/pending_transactions':
      return 'pendingTransactions'
    case path === '/blocks':
      return 'blockHistory'
    case path === '/accounts':
      return 'allAccounts'
    case path.includes('/blocks') && path.includes('/transactions'):
      return 'blockTransactions'
    case path.includes('/blocks') && path.includes('/signers'):
      return 'blockSigners'
    case path.includes('/address') && path.includes('/transactions'):
      return 'addressDetails'
    case path.includes('/address') && path.includes('/token_transfers'):
      return 'addressTokenTransfers'
    case path.includes('/address') && path.includes('/tokens'):
      return 'addressTokens'
    case path.includes('/address') && path.includes('/internal_transactions'):
      return 'addressInternalTransactions'
    case path.includes('/address') && path.includes('/coin_balances'):
      return 'addressCoinHistory'
    case path.includes('/address') && path.includes('/logs'):
      return 'addressLogs'
    case path.includes('/address') && path.includes('/signed'):
      return 'addressDowntime'
    case path.includes('/address') && path.includes('/validations'):
      return 'addressBlocksValidated'
    case path.includes('/address') && path.includes('/celo'):
      return 'addressCeloInfo'
    // TODO: Add rest of contract pages
    case path.includes('/address') && path.includes('/contracts'):
      return 'contractAddressCode'
    case path.includes('/address') && path.includes('/read_contract'):
      return 'readContract'
    case path.includes('/tx') && path.includes('/internal_transactions'):
      return 'transactionInternalTransaction'
    case path.includes('/tx') && path.includes('/logs'):
      return 'transactionLogs'
    case path.includes('/tx') && path.includes('/raw_trace'):
      return 'transactionRawTrace'
    case path.includes('/tx') && path.includes('/token_transfers'):
      return 'transactionTokenTransfers'
    default:
      return 'unknown'
  }
}

// returns referrer path, strips domain name from referrer
function getReferrerPath () {
  const referrer = document.referrer
  return referrer.replace('https://explorer.celo.org', '').replace('http://localhost:4000', '')
}

// returns relevant entity ID: Address, Transaction, Block, or Search Parameter
function getEntityId (path) {
  const pathSegments = window.location.pathname.split('/')
  for (var i = 0; i < pathSegments.length; i++) {
    if (pathSegments[i].includes('search')) {
      return window.location.search.slice(3)
    } else if (pathSegments[i] === 'blocks' && pathSegments[i + 1]) {
      return pathSegments[i + 1]
    } else if (pathSegments[i].slice(0, 2) === '0x') {
      return pathSegments[i]
    }
  }
}

// returns blockscout network: Mainnet, Alfajores or Baklava
function getNetwork () {
  switch (window.location.host) {
    case 'explorer.celo.org':
      return 'mainnet'
    case 'alfajores-blockscout.celo-testnet.org':
      return 'alfajores'
    case 'baklava-blockscout.celo-testnet.org':
      return 'baklava'
    default:
      return 'mainnet'
  }
}

// returns timezone offset
function getTimezoneOffset () {
  var d = new Date()
  return d.getTimezoneOffset()
}

// returns data related to all analytics events
function getCommonData () {
  return {
    uniqueUserId: store.getState().userID,
    timestamp: Date.now(),
    timezoneOffset: getTimezoneOffset(),
    userAgent: navigator.userAgent,
    network: getNetwork()
  }
}

// track page navigation
function trackPage () {
  const path = window.location.pathname

  analytics.track('navigation', {
    targetName: getPageName(path),
    sourcePage: getPageName(getReferrerPath()),
    sourceModule: '',
    entityId: getEntityId(path),
    ...getCommonData()
  })
}

function trackEvents () {
  $(function () {
    // Page navigation
    window.addEventListener('locationchange', function () {
      trackPage()
    })

    // Search box click
    $('[data-selector="search-bar"]').on('click', function () {
      const path = window.location.pathname
      analytics.track('click', {
        targetName: 'searchBox',
        page: getPageName(path),
        ...getCommonData()
      })
    })

    // Search submit
    $('[data-selector="search-form"]').on('submit', function (e) {
      const path = window.location.pathname
      analytics.track('search', {
        targetName: 'search',
        page: getPageName(path),
        query: e.target.value,
        ...getCommonData()
      })
    })

    // Click on Balance Card Caret
    $('[data-selector="balance-card"]').on('click', function () {
      const path = window.location.pathname
      analytics.track('click', {
        targetName: 'balanceDetail',
        page: getPageName(path),
        entityId: getEntityId(path),
        ...getCommonData()
      })
    })

    // Copy address
    $('[data-selector="copy-address"]').on('click', function () {
      const path = window.location.pathname
      analytics.track('click', {
        targetName: 'copyAddress',
        page: getPageName(path),
        entityId: getEntityId(path),
        ...getCommonData()
      })
    })

    // QR code
    $('[data-selector="qr-code"]').on('click', function () {
      const path = window.location.pathname
      analytics.track('click', {
        targetName: 'displayQR',
        page: getPageName(path),
        entityId: getEntityId(path),
        ...getCommonData()
      })
    })

    // "view more transfers" click
    $('[data-selector="token-transfer-open"]').on('click', function () {
      const path = window.location.pathname
      const entityId = $(this).parent().siblings()[0].innerText
      analytics.track('click', {
        targetName: 'viewMore',
        page: getPageName(path),
        module: 'tokenTransferOverview',
        entityId,
        ...getCommonData()
      })
    })
  })
}

// initiate analytics and store
function initAnalytics (segmentKey) {
  // instantiate analytics
  analytics = Analytics({
    app: 'Blockscout',
    plugins: [
      segmentPlugin({
        writeKey: segmentKey
      })
    ]
  })

  // instantiate store
  store = createStore(reducer)
  if (!store.getState().userID) {
    store.dispatch({ type: 'SET_USER_ID' })
  }

  // initial analytics
  analytics.identify(store.getState().userID)
  trackPage()

  // track analytics events
  trackEvents()
}

// get analytics key env var
(function () {
  const analyticsKey = window.ANALYTICS_KEY || 'invalid key' // defined globally
  initAnalytics(analyticsKey)
})()
