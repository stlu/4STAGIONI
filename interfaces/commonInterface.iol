// tipi di dato e operazioni condivise tra Market, Player(s), Stock(s)

// tipo di dato relativo ai fault StockDuplicatedException, StockUnknownException, StockAvailabilityException
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

//Il tipo di dato utilizzato dal market per la comunicazione con MonitorX,
//è lo stesso per ogni operazione, a seconda dell'operazione alcuni campi
//sono riempiti, altri no
type OutData: void {
    .screen: int
    .type: string
    .stockName?: string
    .playerName?: string
    .ownedStockNames[0,*]: string
    .ownedStockQuantities[0,*]: int
    .registeredStocks[0,*]: string
    .totalPrices[0,*]: double
    .availability?: int
    .variation?: double
}
