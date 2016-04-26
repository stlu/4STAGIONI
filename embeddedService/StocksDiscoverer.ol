include "../config/config.iol"
include "file.iol" // è necessario poichè sono rilanciati vari fault definiti in questa interfaccia
include "../behaviour/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "xml_utils.iol"

inputPort StocksDiscoverer {
	Location: "local"
	Interfaces: StocksDiscovererInterface
}

execution { sequential }

main {

	[ discover( stockList )( response ) {

		install(
					StocksDiscovererFault => throw( StocksDiscovererFault ),

					IOException => throw( IOException ),
					FileNotFound => throw( FileNotFound )
				);


		println@Console( "\nStocksDiscoverer@discover, stockList:" )();
		valueToPrettyString@StringUtils( stockList )( result );
		println@Console( result )();

// estraggo i files di configurazione degli stock dal basepath definito in ../config/config.iol
		listRequest.directory = configPath_stocks;
		listRequest.regex = ".+\\.xml";
		listRequest.order.byname = true;
		list@File( listRequest )( listResult );

// alias
		fileList -> stockList.filename;
		nameList -> stockList.name;

		listCount = #fileList - 1;

		newStocksCount = 0;

// è presente almeno un file all'interno della directory?
		if ( #listResult.result > 0 ) {

// estraggo ciascun file xml dal path indicato ed effettuo 2 verifiche: una sul filename, l'altra sul nome dello stock;
// qualora il filename non sia già presente all'interno della lista degli stock correnti,
// allora posso verificare il nome dello stock in esso contenuto;
// qualora anche il nome non sia già presente, allora posso lanciare lo stock a runtime (operazione di cui si occuperà StockMsg.ol)
			for ( k = 0, k < #listResult.result, k++ ) {
				currentFile = listResult.result[ k ];

				println@Console( "StocksDiscoverer@discover analizzo " + currentFile)();

				found = false;
				for ( j = 0, j < #fileList, j++ ) {
// il file corrente non è presente nella lista, posso estrarre le informazioni contenute e verificare il nome dello stock
					if ( currentFile == fileList[ j ] ) {
						found = true;
						j = #fileList // forzo l'interruzione del ciclo
					}
				};

				if ( found == false ) {

					println@Console( "\til file corrente (" + currentFile + ") non è presente nella lista! ")();

// inserisco il file corrente all'interno di fileList, così da prevenire ulteriori match
					listCount++;
					fileList[ listCount ] = currentFile;

// procedo con la lettura del file xml
					filePath = configPath_stocks + currentFile;
					exists@File( filePath )( fileExists );

					if ( fileExists ) {

/*
						with ( fileInfo ) {
								.filename = filePath;
								.format[0] = "xml";
								.format[0].charset[0] = "UTF-8"
						};

						readFile@File( fileInfo )( xmlTree );
						valueToPrettyString@StringUtils( xmlTree )( result );
						println@Console( result )();				
*/

/*
type XMLToValueRequest:any { 
    .options?:void { 
        .includeAttributes?:bool
        .schemaUrl?:string
        .charset?:string
        .schemaLanguage?:string
    }
}
*/

						fileInfo.filename = filePath;
						println@Console( "reading from " + filePath )();
						readFile@File( fileInfo )( xmlTree );

//						valueToPrettyString@StringUtils( xmlTree )( result );			

//						xmlTree.options.schemaUrl = "../config/schema.xsd";
						xmlTree.options.charset = "UTF-8";
						xmlTree.options.schemaLanguage = "it";

// todo: catch typeMismatch fault
// la seguente operazione può lanciare un TypeMismatchfault qualora l'attributo _jolie_type non sia congruo con il valore
// indicato; ricorda che non è incluso il nodo radice <stock>
						xmlToValue@XmlUtils( xmlTree )( xmlParsedTree );						

/*
						valueToPrettyString@StringUtils( xmlParsedTree )( result );
						println@Console( result )();
*/
						
// il nome dello stock è presente nella lista?
// estraggo il nome dello stock dalla struttura xml e lo confronto con ciascun nome già presente nella lista
						found = false;
						for ( j = 0, j < #nameList, j++ ) {
							if ( nameList[ j ] == xmlParsedTree.name ) {
								found = true
							}
						};

// abbiamo a che fare con un nuovo stock
						if ( found == false ) {
// inserisco il nome corrente all'interno di nameList, così da prevenire ulteriori match
							nameList[ listCount ] = currentFile;
// aggiorno la struttura dati con un parametro non presente nell'xml ma specificato nell'interfaccia
							xmlParsedTree.filename = currentFile;

/*
							xmlTree.stock.filename = currentFile;
							response.stock[ newStocksCount ].static[0] << xmlTree.stock;
							response.stock[ newStocksCount ].dynamic.availability = xmlTree.stock.availability;
							response.stock[ newStocksCount ].dynamic.price = xmlTree.stock.price;
*/

/*
beh, non funziona! Cioè, non posso iniziare a popolare una struttura dati da un indice > 0
							stocksStructureIndex = newStocksCount + #fileList - 1;			
							response.stock[ stocksStructureIndex ].static << xmlParsedTree;
							response.stock[ stocksStructureIndex ].dynamic.availability = xmlParsedTree.info.availability;
							response.stock[ stocksStructureIndex ].dynamic.price = xmlParsedTree.info.price;
*/

							response.stock[ newStocksCount ].static << xmlParsedTree;
							response.stock[ newStocksCount ].dynamic.availability = xmlParsedTree.info.availability;
							response.stock[ newStocksCount ].dynamic.price = xmlParsedTree.info.price;

							newStocksCount++;

							println@Console( "found new stock: " + xmlParsedTree.name )()
						}

// todo: sarebbe più corretto lanciare un fault
					} else {
						println@Console( filePath + " not found" )()
					}
				}
			}
		};

		if ( newStocksCount <= 0 ) {
			with( stocksDiscovererFaultType ) {
				.msg = "StocksDiscoverer@discover fault: the stock list is up to date"
			};
			throw( StocksDiscovererFault, stocksDiscovererFaultType )
		}
		
	} ] { nullProcess }
}