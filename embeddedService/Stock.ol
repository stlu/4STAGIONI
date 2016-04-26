include "../config/config.iol"
include "file.iol"
include "../behaviour/stockInterface.iol"

include "console.iol"
include "string_utils.iol"

inputPort StockInstance {
	Location: "local"
	Interfaces: StockInstanceInterface
}

/*
Jolie allows OUTPUT ports to be dynamically bound, i.e., their locations and protocols (called binding informations)
can change at runtime. Changes to the binding information of an output port is local to a behaviour instance: 
output ports are considered part of the local state of each instance. Dynamic binding is obtained by treating output 
ports as variables.

quindi, ecco la fregatura.. niente dynamic binding sulle input port!
*/

// lo stock comunica in forma autonoma con il market per richieste in output
outputPort StockToMarketCommunication {
	Location: "socket://localhost:8001"
	Protocol: sodep
	Interfaces: StockToMarketCommunicationInterface
}

execution { concurrent }

main {

// riceve in input la struttura dati di configurazione del nuovo stock (StockSubStruct)
	[ start( stockConfig )( response ) {
		println@Console( "ho appena avviato un client stock (" + stockConfig.static.name + ")")();
// avvio la procedura di registrazione dello stock sul market
		register@StockToMarketCommunication( stockConfig.static.name )();

		global.stockConfig << stockConfig

	} ] { nullProcess }

	[ buyStock( request )( response ) {
//		response = "Sono " + global.stockConfig.static.name + "; il market ha appena richiesto @buyStock"
		response = "Sono " + request + "; il market ha appena richiesto @buyStock"
	} ] { nullProcess }

	[ sellStock( request )( response ) {
		response = "response"
	} ] { nullProcess }

}