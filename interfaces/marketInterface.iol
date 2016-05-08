type MarcketStatus: bool {
  .message: string
}

// Interfaccia di comunicazione con il Market
interface MarketCommunicationInterface {
    RequestResponse:
        checkMarketStatus( void )( MarcketStatus )
}
