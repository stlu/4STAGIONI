type infoStockStruct: void {
    .name[0,*]: string
}

/*
 * Strutture del tipo di dato PlayerStatus e del tipo di dato stockQuantity
 * usato  per rappresentare una quantità di un certo stock posseduta dal player.
 */
type PlayerStatus: void {
    .name: string
    .ownedStock*: StockQuantity
    .liquidity: double
}

type StockQuantity: void {
    .name: string
    .quantity: int
}

interface PlayerToMarketCommunicationInterface {
    RequestResponse:
        registerPlayer( string )( PlayerStatus ),
        buyStock( string )( string ),
        sellStock( string )( string ),
        infoStockList( string )( infoStockStruct ),
        infoStockPrice( string )( double ),
        infoStockAvaliability( string )( double )
}
