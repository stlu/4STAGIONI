// di seguito è descritta la struttura dati utilizzata per la gestione degli stock
type Stocks: void {
	.stock[0,*]: StockSubStruct
}

type StockSubStruct: void {
	.static: StockStaticStruct
	.dynamic: StockDynamicStruct
}

// informazioni caricate dal file di configurazione xml
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
	.price: double
}

// struttura dati "light" utilizzata nel processo di discovering di nuovi stock
// (contrapposta a dynamicStockList congeniata per semplificare il dynamic lookup)
type IndexedStockList: void {
	.filename[0,*]: string
	.name[0,*]: string
}

type StocksDiscovererFaultType: void {
	.msg: string
}

// connette StocksLauncher e StocksMng
// forse meglio utilizzare una OneWay per discoverStocks?
interface StocksLauncherInterface {
	RequestResponse: discover( void )( void )
}

// input: una file list di stocks già presenti;
// output: una struttura dati di tipo Stocks da "mergiare" con quella presente a runtime
interface StocksDiscovererInterface {
	RequestResponse: discover( IndexedStockList )( Stocks ) throws 	StocksDiscovererFault( StocksDiscovererFaultType )
																	IOException( IOExceptionType )
																	FileNotFound( FileNotFoundType )
}

// interfaccia di comunicazione con ciascuna stock instance dinamicamente allocata
interface StockInstanceInterface {
	RequestResponse: start( StockSubStruct )( void )
	RequestResponse: buyStock( string )( string )
	RequestResponse: sellStock( string )( string )	
}

// from stocks to market
interface StockToMarketCommunicationInterface {
	RequestResponse: register( string )( string )
	RequestResponse: addStock( string )( string )
	RequestResponse: destroyStock( string )( string )
}

// from market to stocks
interface MarketToStockCommunicationInterface {
	RequestResponse: buyStock( string )( string )
	RequestResponse: sellStock( string )( string )
}