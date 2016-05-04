interface PlayerToMarketCommunicationInterface {
    RequestResponse: buyStock( string )( string )
    RequestResponse: sellStock( string )( string )
    RequestResponse: infoStockList( void )( void )
    RequestResponse: infoStockPrice( string )( double )
    RequestResponse: infoStockAvaliability( string )( double )
    RequestResponse: registerPlayer( string )( bool )
}
