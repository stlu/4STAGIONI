type infoStockStruct: void {
    .name[0,*]: string
}

/*
 * Strutture del tipo di dato PlayerStatus e del tipo di dato stockQuantity
 * usato  per rappresentare una quantità di un certo stock posseduta dal player.
 */
type PlayerStatus: string {
    .ownedStock*: StockQuantity
    .liquidity: double
}

type StockQuantity: string {
    .quantity: int
}

/*
 * Struttura del tipo di dato Receipt, con il quale il market informa il player
 * dell'esito di una buy/sell e del prezzo al quale è avvenuta la transazione
 */
type Receipt: void {
    .stock: string
    .kind: int //Può essere solo +1 o -1
    .esito: bool
    .price: double //E' positivo o negativo a seconda del tipo di transazione
}

/*
* Struttura del tipo di dato TransactionRequest, contiene semplicemente
* il nome del Player richiedente e lo stock in questione
*/
type TransactionRequest: void {
    .player: string
    .stock: string
}

interface PlayerToMarketCommunicationInterface {
    RequestResponse:
        registerPlayer( string )( PlayerStatus ) throws PlayerDuplicateException,
        buyStock( TransactionRequest )( Receipt ) throws StockUnknownException,
        sellStock( TransactionRequest )( Receipt ) throws StockUnknownException,
        infoStockList( string )( infoStockStruct ),
        infoStockPrice( string )( double ),
        infoStockAvailability( string )( double )
}
