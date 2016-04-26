include "../config/config.iol"
include "file.iol"
include "../behaviour/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "xml_utils.iol"

include "runtime.iol"
include "time.iol"

// embedded by StocksLauncher
inputPort StocksMng {
	Location: "local"
	Interfaces: StocksLauncherInterface
}

// embeds StocksDiscoverer
outputPort StocksDiscoverer {
	Interfaces: StocksDiscovererInterface
}

// comunica con ciascun stock client dinamicamente allocato
// embeds n stock instances
outputPort StockInstance {
	Interfaces: StockInstanceInterface
}

// raccoglie le informazioni provenienti dal mercato rispetto alle operazioni di buy e sell e le inoltra alla specifica
// istanza di stock
inputPort MarketToStockCommunication {
	Location: "socket://localhost:8000"
	Protocol: sodep
	Interfaces: MarketToStockCommunicationInterface
}

embedded {
	Jolie:
		"StocksDiscoverer.ol" in StocksDiscoverer
}

execution { concurrent }

init {
	global.dynamicStockList = ""
}

main {

// sulle operazioni buyStock e sellStock sono ricevute chiamate "aggregate" per tutti gli stock client in esecuzione
// StocksMng svolge le veci di proxy tra il market e ciascun stock
// (mentre per le chiamate in uscita, ciascun stock è assolutamente indipendente, ovvero dialoga con il market direttamente)
// il motivo di tali scelte? Sostanzialmente l'assenza del dynamic binding sulle input port che, tradotto in altri termini,
// non permette la definizione dinamica delle input port sulle singole istanze del thread stock.

// ricorda la composizione della struttura dynamicStockList (su cui è applicabile il dynamic lookup)
// dynamicStockList.( stockName )[ 0 ].fileName
// dynamicStockList.( stockName )[ 0 ].location
	[ buyStock( stockName )( response ) {

// dynamic lookup rispetto alla stringa stockName
		if ( is_defined( global.dynamicStockList.( stockName )[ 0 ] )) {
// per comunicare con la specifica istanza, imposto a runtime la location della outputPort StockInstance
			StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
// posso adesso avviare l'operazione sullo specifico stock
			
//			buyStock@StockInstance()( response )
			buyStock@StockInstance( stockName )( response )
		} else {

// todo: meglio lanciare un fault...
			response = "TypeMismatch"
		}

	} ] { nullProcess }

	[ sellStock( request )( response ) {
		response = request
	} ] { nullProcess }	



// operazione invocata da StocksLauncher
	[ discover( request )( response ) {

		while ( true ) {

			scope ( stocksDiscovery ) {
				install(
							// stock list up to date
							StocksDiscovererFault => println@Console( stocksDiscovery.StocksDiscovererFault.msg )(),

							IOException => throw( IOException ),
							FileNotFound => throw( FileNotFound )
						);

// trasformo la dynamicStockList in una indexedStockList (ad uso e consumo di StocksDiscoverer)
// per maggiori dettagli si veda la struttura dati definita nell'interfaccia
				k = 0;
				foreach ( stockName : global.dynamicStockList ) {
					indexedStockList.filename[ k ] = global.dynamicStockList.( stockName )[ 0 ].filename;
					indexedStockList.name[ k ] = stockName;
//					println@Console( indexedStockList[ j ].filename + " " + indexedStockList[ j ].name )();
					k++
				};

				valueToPrettyString@StringUtils( indexedStockList )( result );
				println@Console( result )();

// avvio la procedura di ricerca ed estrazione di nuovi stock
				discover@StocksDiscoverer( indexedStockList )( newStocks )
			};

// il seguente scope si occupa di lanciare nuove istanze del servizio Stock.ol in relazione ai nuovi files xml inseriti
			scope ( stocksLauncher ) {
				install(
							RuntimeExceptionType => throw( RuntimeExceptionType )
						);

// sono stati individuati nuovi files xml (cioè nuovi stock); è richiesto l'avvio di nuove istanze
				if ( #newStocks.stock > 0 ) {

					embedInfo.type = "Jolie";
					embedInfo.filepath = "Stock.ol";

					for ( k = 0, k < #newStocks.stock, k++ ) {
						stockName = newStocks.stock[ k ].static.name;
						stockFilename = newStocks.stock[ k ].static.filename;
						println@Console( "\nStocksMng@stocksLauncher scope: starting new stock instance (" + 
											stockName + " / " + stockFilename + ")" )();

// lancia una nuova istanza dello stock
// loadEmbeddedService returns the (local) location of the embedded service
						loadEmbeddedService@Runtime( embedInfo )( StockInstance.location );

// qualora l'istruzione precedente non abbia generato alcun fault
// aggiorno la dynamicStockList; il parametro location è di vitale importanza
						global.dynamicStockList.( stockName )[ 0 ].location = StockInstance.location;
						global.dynamicStockList.( stockName )[ 0 ].filename = stockFilename;

// avvia la registrazione dello stock sul market
						start@StockInstance( newStocks.stock[ k ] )()
					}
				}
			};

			undef ( newStocks );
			sleep@Time( 5000 )()
		} // while

	} ] { nullProcess }
}