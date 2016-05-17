// tipi di dato e operazioni condivise tra Market, Player(s), Stock(s)

// tipo di dato relativo al fault StockDuplicatedException
type StockNameExceptionType: void {
    .stockName: string
}

type MarketStatus: bool {
    .message: string
}

// interfaccia di comunicazione con il Market (utilizzata sia lato stock che lato player)
interface MarketCommunicationInterface {
    RequestResponse: checkMarketStatus( void )( MarketStatus )
}