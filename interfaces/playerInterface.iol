type infoStockStruct: void {
    .name[0,*]: string
}

interface PlayerToMarketCommunicationInterface {
    RequestResponse: buyStock( string )( string )
    RequestResponse: sellStock( string )( string )
    RequestResponse: infoStockList( string )( infoStockStruct )
    RequestResponse: infoStockPrice( string )( double )
    RequestResponse: infoStockAvaliability( string )( double )
    RequestResponse: registerPlayer( string )( bool )
}
