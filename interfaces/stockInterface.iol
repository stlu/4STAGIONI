type Stocks: void {
    .stock[0,*]: StockSubStruct
}

type StockSubStruct: void {
    .static: StockStaticStruct
    .dynamic: StockDynamicStruct
}

// informazioni caricate dal file di configurazione xml (filename è aggiunto a runtime)
type StockStaticStruct: void {
    .filename: string
    .name: string
    .info: void {
        .availability: int
        .price: double
        .wasting: void {
            .low: int
            .high: int
            .interval: int
        }
        .production: void {
            .low: int
            .high: int
            .interval: int
        }
    }
}

// informazioni a runtime dello specifico stock
type StockDynamicStruct: void {
    .availability: int
}

type StocksDiscovererFaultType: void {
    .msg: string
}

type StockRegistrationStruct: void {
    .name: string
    .price: double
}

// struttura dati utilizzata dallo stock per comunicare al market la variazione di produzione / deperimento
type StockVariationStruct: void {
    .name: string
    .variation: double
}



// connette StocksLauncher e StocksMng
interface StocksLauncherInterface {
    RequestResponse: discover( int )( void ) throws     StocksDiscovererFault( StocksDiscovererFaultType )
                                                        IOException( IOExceptionType )
                                                        FileNotFound( FileNotFoundType )
}

// interfaccia di comunicazione con ciascuna stock instance dinamicamente allocata (ed embeddata) all'interno di StocksMng.ol
interface StockInstanceInterface {
// todo: cosa posso aspettarmi come dato in risposta all'avvio di una nuova istanza di stock?
// dovrebbe propagare la risposta dell'operazione registerStock sul market?
    RequestResponse: start( StockSubStruct )( void )

    RequestResponse: buyStock( void )( string ) throws StockUnknownException
    RequestResponse: sellStock( void )( string ) throws StockUnknownException
    RequestResponse:infoStockAvaliability( void )( double )
}

// from stocks to market
interface StockToMarketCommunicationInterface {
    RequestResponse: registerStock( StockRegistrationStruct )( string ) throws StockDuplicateException,
                                                                               IOException

    OneWay: addStock( StockVariationStruct )
    OneWay: destroyStock( StockVariationStruct )
}

// from market to stocks (passando per StocksMng.ol)
interface MarketToStockCommunicationInterface {
    RequestResponse: buyStock( string )( string ) throws StockUnknownException
    RequestResponse: sellStock( string )( string ) throws StockUnknownException
    RequestResponse:infoStockAvaliability( string )( double )
}
