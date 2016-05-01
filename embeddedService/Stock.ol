include "../config/config.iol"
include "file.iol"
include "../deployment/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "runtime.iol"
include "time.iol"
include "math.iol"



// le seguenti definizioni di interfaccia e outputPort consento un'invocazione "riflessiva" 
interface LocalInterface { 
	OneWay: wasting( void ) // deperimento
	OneWay: production( void ) // produzione
}
outputPort Self { Interfaces: LocalInterface }

// porta in ascolto per la comunicazione con l'embedder (StocksMng)
inputPort StockInstance {
	Location: "local"
	Interfaces: StockInstanceInterface, LocalInterface
}

/*
Jolie allows OUTPUT ports to be dynamically bound, i.e., their locations and protocols (called binding informations)
can change at runtime. Changes to the binding information of an output port is local to a behaviour instance: 
output ports are considered part of the local state of each instance. Dynamic binding is obtained by treating output 
ports as variables.
d'accordo, niente dynamic binding sulle input port. Però, per quanto sembra di capire, non si presenta alcuna race condition
per la scrittura della location sulla output port e quindi per la comunicazione con lo stock.
*/

// lo stock comunica in forma autonoma con il market per richieste in output
outputPort StockToMarketCommunication {
	Location: "socket://localhost:8001"
	Protocol: sodep
	Interfaces: StockToMarketCommunicationInterface
}



define randGen {
// Returns a random number d such that 0.0 <= d < 1.0.
	random@Math()( rand );
// genera un valore random, estremi inclusi	
	amount = int(rand * (upperBound - lowerBound + 1) + lowerBound)
}



execution { concurrent }

main {

// riceve in input la struttura dati di configurazione del nuovo stock (StockSubStruct)
	[ start( stockConfig )( response ) {
		getProcessId@Runtime()( processId );
		println@Console( "ho appena avviato un client stock (" + stockConfig.static.name + "), (" + processId + ")")();

		global.stockConfig << stockConfig;

// avvio la procedura di registrazione dello stock sul market
// compongo una piccola struttura dati con le uniche informazioni richieste dal market
		registrationStruct.name = stockConfig.static.name;
		registrationStruct.price = stockConfig.static.info.price;
		registerStock@StockToMarketCommunication( registrationStruct )( response );

// who I am?
		getLocalLocation@Runtime()( Self.location );

// posso adesso avviare l'operazione di wasting (deperimento), ovvero un thread parallelo e indipendente (definito
// come operazione all'interno del servizio Stock) dedicato allo svolgimento di tal operazione
		if ( stockConfig.static.info.wasting.interval > 0 ) {
			wasting@Self()
		};

// idem per production (leggi sopra)
		if ( stockConfig.static.info.production.interval > 0 ) {
			production@Self()
		}

	} ] { nullProcess }

	[ buyStock()( response ) {

		getProcessId@Runtime()( processId );

		me -> global.stockConfig;
		println@Console( "Sono " + me.static.name + " (" + processId + "); il market ha appena richiesto @buyStock" )();

		synchronized( syncToken ) {
			if ( me.dynamic.availability > 0 ) {
				me.dynamic.availability--;
				response = "Sono " + me.static.name + " (" + processId + "); decremento la disponibilità di stock"
			} else {

// todo: lanciare un fault
				response = "Sono " + me.static.name + " (" + processId + "); la disponibilità è terminata"
			}
		}

	} ] { nullProcess }

// riflettere: possono presentarsi casistiche per le quali sia necessario sollevare un fault?
	[ sellStock()( response ) {
		getProcessId@Runtime()( processId );

		me -> global.stockConfig;
		println@Console( "Sono " + me.static.name + " (" + processId + "); il market ha appena richiesto @sellStock" )();

		synchronized( syncToken ) {
			me.dynamic.availability++;
			response = "Sono " + me.static.name + " (" + processId + "); incremento la disponibilità di stock"
		}
	} ] { nullProcess }

// OneWay riflessivo; operazione di deperimento di unità dello stock
	[ wasting() ] {

		getProcessId@Runtime()( processId );

		me -> global.stockConfig;
		me.wasting -> me.static.info.wasting;
		println@Console( "Sono " + me.static.name + " (" + processId + "); ho appena avviato la procedura di wasting" )();

		while ( true ) {
			synchronized( syncToken ) {
// la quantità residua è sufficiente per effettuare un deperimento				
				if ( me.dynamic.availability >= me.wasting.high ) {
					lowerBound = me.wasting.low;
					upperBound = me.wasting.high;
					randGen;
					me.dynamic.availability -= amount;

					println@Console( "Sono " + me.static.name + " (" + processId + "); WASTING di " + amount + 
										" (" + me.dynamic.availability + "); interval: " + me.wasting.interval + " secondi" )()
				}
			};

			sleep@Time( me.wasting.interval * 1000 )()
		}
	}

// OneWay riflessivo; operazione di produzione di nuove unità di stock
	[ production() ] {
		getProcessId@Runtime()( processId );

		me -> global.stockConfig;
		me.production -> me.static.info.production;
		println@Console( "Sono " + me.static.name + " (" + processId + "); ho appena avviato la procedura di production" )();

		while ( true ) {
			synchronized( syncToken ) {
				lowerBound = me.production.low;
				upperBound = me.production.high;
				randGen;
				me.dynamic.availability += amount;

				println@Console( "Sono " + me.static.name + " (" + processId + "); PRODUCTION di " + amount + 
									" (" + me.dynamic.availability + "); interval: " + me.production.interval + " secondi" )()
			};

			sleep@Time( me.production.interval * 1000 )()
		}
	}
}



/*
buyStock
	synchronized {
		availability--
	}

wasting
	synchronized {
		availability--
	}

2 soluzioni
-> semaforo tra buyStock e wasting (rilascio il semaforo solo dopo che ho ricevuto response da market per l'operazione)
-> synchronized su market per l'accesso in scrittura alla struttura dati che contiene prezzo / quantità stock

se è in corso un'operazione di buying, blocco la struttura dati per eventuali wasting in arrivo
*/