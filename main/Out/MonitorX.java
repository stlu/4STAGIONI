package Out;

import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;

import java.util.Locale;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;

public class MonitorX extends JavaService {
    
    private javax.swing.JFrame finestra;
    private javax.swing.JLabel jLabel1;
    private javax.swing.JLabel jLabel2;
    private javax.swing.JLabel jLabel3;
    private javax.swing.JPanel jPanel1;
    private javax.swing.JScrollPane jScrollPane1;
    private javax.swing.JScrollPane jScrollPane2;
    private javax.swing.JScrollPane jScrollPane3;
    private javax.swing.JTextArea jTextArea1;
    private javax.swing.JTextArea jTextArea2;
    private javax.swing.JTextArea jTextArea3;
    
    private AscoltatoreResize res;
    private String separatore;
    private class AscoltatoreResize extends ComponentAdapter {
        @Override
        public void componentResized(ComponentEvent e) {
            int width = jTextArea1.getWidth();
            int trattiniInUnaRiga = (int)Math.floor(width/7.05)-2;
            separatore = "";
            while (trattiniInUnaRiga != 0) {
                separatore += "*";
                --trattiniInUnaRiga;
            }
        }
    }

    /**
     * Creates new form Monitor
     */
    public MonitorX() {
        Locale.setDefault(Locale.US);
        initComponents();
        finestra.addComponentListener(res);
        finestra.setSize(1100, 600);
        finestra.setLocationRelativeTo(null);
        /* Set the Nimbus look and feel */
        //<editor-fold defaultstate="collapsed" desc=" Look and feel setting code (optional) ">
        /* If Nimbus (introduced in Java SE 6) is not available, stay with the default look and feel.
         * For details see http://download.oracle.com/javase/tutorial/uiswing/lookandfeel/plaf.html 
         */
        try {
            for (javax.swing.UIManager.LookAndFeelInfo info : javax.swing.UIManager.getInstalledLookAndFeels()) {
                if ("Nimbus".equals(info.getName())) {
                    javax.swing.UIManager.setLookAndFeel(info.getClassName());
                    break;
                }
            }
        } catch (ClassNotFoundException ex) {
            java.util.logging.Logger.getLogger(MonitorX.class.getName()).log(java.util.logging.Level.SEVERE, null, ex);
        } catch (InstantiationException ex) {
            java.util.logging.Logger.getLogger(MonitorX.class.getName()).log(java.util.logging.Level.SEVERE, null, ex);
        } catch (IllegalAccessException ex) {
            java.util.logging.Logger.getLogger(MonitorX.class.getName()).log(java.util.logging.Level.SEVERE, null, ex);
        } catch (javax.swing.UnsupportedLookAndFeelException ex) {
            java.util.logging.Logger.getLogger(MonitorX.class.getName()).log(java.util.logging.Level.SEVERE, null, ex);
        }
        //</editor-fold>

        /* Create and display the form */
        java.awt.EventQueue.invokeLater(new Runnable() {
            @Override
            public void run() {
                finestra.setVisible(true);
            }
        });
    }
    
    /*
     * Il metodo viene chiamato dall'init di Market.ol, crea e mostra la
     * finestra chiamando il costruttore.
     * A quanto pare chiamare questo metodo vuoto è sufficiente affinche in
     * qualche maniera il costruttore venga chiamato, non so come.
     */
    public void avviaMonitorX() {
    }
    
    public void printOut(Value infoTree) {
        //DATI IN ENTRATA DA JOLIE
        int screenNumber = infoTree.getChildren("screen").get(0).intValue();
        String operationType = infoTree.getChildren("type").get(0).strValue();
        String stockName, playerName;
        int availability;
        double percentVariation;
        //Semplici array
        ValueVector ownedStockNames, ownedStockQuantities, registeredStocks,
               totalPrices;
        //Supporto alla formattazione
        String nextLine;
        
        switch (screenNumber) {
            //Schermo 1 - PLAYERS
            case 1: {
                switch (operationType) {
                    case "playerRegistration": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        jTextArea1.append(playerName.toUpperCase()+"\n" +
                                "Registrazione effettuata, ottenuto account\n");
                        break;
                    }
                    case "buyStock": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        ownedStockNames = infoTree.getChildren("ownedStockNames");
                        ownedStockQuantities = infoTree.getChildren("ownedStockQuantities");
                        nextLine = playerName.toUpperCase()+" <<< "+stockName+
                                endCol(playerName+" <<< "+stockName);
                        int indx = 0;
                        do {
                            nextLine += ownedStockNames.get(indx).strValue()+": "+
                                    endCol2(ownedStockNames.get(indx).strValue()+": ")+
                                    ownedStockQuantities.get(indx).intValue();
                            if(ownedStockNames.get(indx).strValue().equals(stockName)) {
                                nextLine += " +";
                            }
                            if(indx==0)
                                jTextArea1.append(nextLine+"\n");
                            else
                                jTextArea1.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<ownedStockNames.size());
                        break;
                    }
                    case "sellStock": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        ownedStockNames = infoTree.getChildren("ownedStockNames");
                        ownedStockQuantities = infoTree.getChildren("ownedStockQuantities");
                        nextLine = playerName.toUpperCase()+" >>> "+stockName+
                                endCol(playerName+" >>> "+stockName);
                        int indx = 0;
                        do {
                            nextLine += ownedStockNames.get(indx).strValue()+": "+
                                    endCol2(ownedStockNames.get(indx).strValue()+": ")+
                                    ownedStockQuantities.get(indx).intValue();
                            if(ownedStockNames.get(indx).strValue().equals(stockName)) {
                                nextLine += " -";
                            }
                            if(indx==0)
                                jTextArea1.append(nextLine+"\n");
                            else
                                jTextArea1.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<ownedStockNames.size());
                        break;
                    }
                }
                jTextArea1.append(separatore+"\n");
                jTextArea1.setCaretPosition(jTextArea1.getDocument().getLength());
                break;
            }
            //Schermo 2 - MARKET
            case 2: {
                switch (operationType) {
                    case "stockRegistration": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        jTextArea2.append("Registrazione nuovo stock: "+stockName+"\n");
                        break;
                    }
                    case "playerRegistration": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        jTextArea2.append("Registrazione nuovo player: "+playerName+"\n");
                        break;
                    }
                    case "buyStock": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        registeredStocks = infoTree.getChildren("registeredStocks");
                        totalPrices = infoTree.getChildren("totalPrices");
                        nextLine = playerName+" <<< "+stockName+endCol(playerName+" <<< "+stockName);
                        int indx = 0;
                        do {
                            nextLine += registeredStocks.get(indx).strValue()+": "+
                                    endCol2(registeredStocks.get(indx).strValue()+": ")+
                                    totalPrices.get(indx).doubleValue();
                            if(registeredStocks.get(indx).strValue().equals(stockName)) {
                                nextLine += " +";
                            }
                            if(indx==0)
                                jTextArea2.append(nextLine+"\n");
                            else
                                jTextArea2.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<registeredStocks.size());
                        break;
                    }
                    case "sellStock": {
                        playerName = infoTree.getChildren("playerName").get(0).strValue();
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        registeredStocks = infoTree.getChildren("registeredStocks");
                        totalPrices = infoTree.getChildren("totalPrices");
                        nextLine = playerName+" >>> "+stockName+endCol(playerName+" >>> "+stockName);
                        int indx = 0;
                        do {
                            nextLine += registeredStocks.get(indx).strValue()+": "+
                                    endCol2(registeredStocks.get(indx).strValue()+": ")+
                                    totalPrices.get(indx).doubleValue();
                            if(registeredStocks.get(indx).strValue().equals(stockName)) {
                                nextLine += " -";
                            }
                            if(indx==0)
                                jTextArea2.append(nextLine+"\n");
                            else
                                jTextArea2.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<registeredStocks.size());
                        break;
                    }
                    case "destroyStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        registeredStocks = infoTree.getChildren("registeredStocks");
                        totalPrices = infoTree.getChildren("totalPrices");
                        percentVariation = Double.valueOf(new java.text.DecimalFormat("#.##").format(
                                infoTree.getChildren("variation").get(0).doubleValue()*100));
                        nextLine = stockName+" DEP. "+percentVariation+"%"+
                                endCol(stockName+" DEP. "+percentVariation+"%");
                        int indx = 0;
                        do {
                            nextLine += registeredStocks.get(indx).strValue()+": "+
                                    endCol2(registeredStocks.get(indx).strValue()+": ")+
                                    totalPrices.get(indx).doubleValue();
                            if(registeredStocks.get(indx).strValue().equals(stockName)) {
                                nextLine += " +";
                            }
                            if(indx==0)
                                jTextArea2.append(nextLine+"\n");
                            else
                                jTextArea2.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<registeredStocks.size());
                        break;
                    }
                    case "addStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        registeredStocks = infoTree.getChildren("registeredStocks");
                        totalPrices = infoTree.getChildren("totalPrices");
                        percentVariation = Double.valueOf(new java.text.DecimalFormat("#.##").format(
                                infoTree.getChildren("variation").get(0).doubleValue()*100));
                        nextLine = stockName+" PROD. "+percentVariation+"%"+
                                endCol(stockName+" PROD. "+percentVariation+"%");
                        int indx = 0;
                        do {
                            nextLine += registeredStocks.get(indx).strValue()+": "+
                                    endCol2(registeredStocks.get(indx).strValue()+": ")+
                                    totalPrices.get(indx).doubleValue();
                            if(registeredStocks.get(indx).strValue().equals(stockName)) {
                                nextLine += " -";
                            }
                            if(indx==0)
                                jTextArea2.append(nextLine+"\n");
                            else
                                jTextArea2.append(endCol("")+nextLine+"\n");
                            nextLine = "";
                            ++indx;
                        } while(indx<registeredStocks.size());
                        break;
                    }
                }
                jTextArea2.append(separatore+"\n");
                jTextArea2.setCaretPosition(jTextArea2.getDocument().getLength());
                break;
            }
            //Schermo 3 - STOCKS
            case 3: {
                switch (operationType) {
                    case "stockRegistration": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        jTextArea3.append(stockName.toUpperCase()+"\n"+"Registrazione effettuata\n");
                        break;
                    }
                    case "buyStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        availability = infoTree.getChildren("availability").get(0).intValue();
                        jTextArea3.append("<<< "+stockName.toUpperCase()+" "+endCol("<<< "+stockName)+//Quello spazion prima di endCol è una patch brutta
                                "Availability: "+availability+endCol3(Integer.toString(availability))+" -"+"\n");
                        break;
                    }
                    case "sellStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        availability = infoTree.getChildren("availability").get(0).intValue();
                        jTextArea3.append(">>> "+stockName.toUpperCase()+" "+endCol(">>> "+stockName)+//Quello spazion prima di endCol è una patch brutta
                                "Availability: "+availability+endCol3(Integer.toString(availability))+" +"+"\n");
                        break;
                    }
                    case "destroyStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        percentVariation = Double.valueOf(new java.text.DecimalFormat("#.##").format(
                                infoTree.getChildren("variation").get(0).doubleValue()*100));
                        availability = infoTree.getChildren("availability").get(0).intValue();
                        jTextArea3.append("DEP."+"  "+stockName.toUpperCase()+endCol4(stockName)+
                                " "+percentVariation+"%"+endCol("DEP."+"  "+
                                stockName+endCol4(stockName)+percentVariation+"%")+
                                "Availability: "+availability+endCol3(Integer.toString(availability))+" -"+"\n");
                        break;
                    }
                    case "addStock": {
                        stockName = infoTree.getChildren("stockName").get(0).strValue();
                        percentVariation = Double.valueOf(new java.text.DecimalFormat("#.##").format(
                                infoTree.getChildren("variation").get(0).doubleValue()*100));
                        availability = infoTree.getChildren("availability").get(0).intValue();
                        jTextArea3.append("PROD."+" "+stockName.toUpperCase()+endCol4(stockName)+
                                " "+percentVariation+"%"+endCol("PROD."+" "+
                                stockName+endCol4(stockName)+percentVariation+"%")+
                                "Availability: "+availability+endCol3(Integer.toString(availability))+" +"+"\n");
                        break;
                    }
                }
                jTextArea3.append(separatore+"\n");
                jTextArea3.setCaretPosition(jTextArea3.getDocument().getLength());
                break;
            }
        }
    }
    
    /**
     * Metodi che restituiscono stringhe di n spazi, n è 25(o 10 o 5) meno la
     * lunghezza della stringa in input, il primo metodo aggiunge in coda anche
     * "| ".
     * Molto utile nella tabulazione.
     * 
     * @param String
     * @return String
     */
    private String endCol(String str) {
        int lunghezzaOut  = 22 - str.length();
        String out = "";
        while (lunghezzaOut>0) {
            out += " ";
            lunghezzaOut--;
        }
        out += "| ";
        return out;
    }
    private String endCol2(String str) {
        int lunghezzaOut  = 10 - str.length();
        String out = "";
        while (lunghezzaOut>0) {
            out += " ";
            lunghezzaOut--;
        }
        return out;
    }
    private String endCol3(String str) {
        int lunghezzaOut  = 5 - str.length();
        String out = "";
        while (lunghezzaOut>0) {
            out += " ";
            lunghezzaOut--;
        }
        return out;
    }
    private String endCol4(String str) {
        int lunghezzaOut  = 9 - str.length();
        String out = "";
        while (lunghezzaOut>0) {
            out += " ";
            lunghezzaOut--;
        }
        return out;
    }
    
    /**
     * This method is called from within the constructor to initialize the form.
     * WARNING: Do NOT modify this code. The content of this method is always
     * regenerated by the Form Editor.
     */
    @SuppressWarnings("unchecked")
    // <editor-fold defaultstate="collapsed" desc="Generated Code">                          
    private void initComponents() {
        
        finestra = new javax.swing.JFrame();
        jPanel1 = new javax.swing.JPanel();
        jScrollPane3 = new javax.swing.JScrollPane();
        jTextArea3 = new javax.swing.JTextArea();
        jScrollPane2 = new javax.swing.JScrollPane();
        jTextArea2 = new javax.swing.JTextArea();
        jScrollPane1 = new javax.swing.JScrollPane();
        jTextArea1 = new javax.swing.JTextArea();
        jLabel1 = new javax.swing.JLabel();
        jLabel2 = new javax.swing.JLabel();
        jLabel3 = new javax.swing.JLabel();
        
        res = new AscoltatoreResize();

        finestra.setDefaultCloseOperation(javax.swing.WindowConstants.DISPOSE_ON_CLOSE);
        finestra.setTitle("jExchange - [MonitorX]");
        finestra.setBackground(java.awt.Color.BLACK);
        finestra.setCursor(new java.awt.Cursor(java.awt.Cursor.DEFAULT_CURSOR));
        finestra.setForeground(java.awt.Color.black);

        jPanel1.setBackground(new java.awt.Color(0, 0, 0));
        jPanel1.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        jPanel1.setForeground(new java.awt.Color(0, 0, 0));

        jScrollPane3.setBorder(javax.swing.BorderFactory.createEmptyBorder(1, 1, 1, 1));

        jTextArea3.setEditable(false);
        jTextArea3.setBackground(new java.awt.Color(0, 0, 0));
        jTextArea3.setColumns(20);
        jTextArea3.setFont(new java.awt.Font("Liberation Mono", 1, 11)); // NOI18N
        jTextArea3.setForeground(new java.awt.Color(255, 255, 255));
        jTextArea3.setLineWrap(true);
        jTextArea3.setRows(5);
        jTextArea3.setWrapStyleWord(true);
        jTextArea3.setBorder(javax.swing.BorderFactory.createEmptyBorder(2, 3, 1, 1));
        jTextArea3.setCursor(new java.awt.Cursor(java.awt.Cursor.DEFAULT_CURSOR));
        jTextArea3.setSelectedTextColor(new java.awt.Color(0, 0, 0));
        jTextArea3.setSelectionColor(new java.awt.Color(0, 255, 0));
        jScrollPane3.setViewportView(jTextArea3);

        jScrollPane2.setBorder(javax.swing.BorderFactory.createEmptyBorder(1, 1, 1, 1));

        jTextArea2.setEditable(false);
        jTextArea2.setBackground(new java.awt.Color(0, 0, 0));
        jTextArea2.setColumns(20);
        jTextArea2.setFont(new java.awt.Font("Liberation Mono", 1, 11)); // NOI18N
        jTextArea2.setForeground(new java.awt.Color(255, 255, 255));
        jTextArea2.setLineWrap(true);
        jTextArea2.setRows(5);
        jTextArea2.setWrapStyleWord(true);
        jTextArea2.setBorder(javax.swing.BorderFactory.createEmptyBorder(2, 3, 1, 1));
        jTextArea2.setCursor(new java.awt.Cursor(java.awt.Cursor.DEFAULT_CURSOR));
        jTextArea2.setSelectedTextColor(new java.awt.Color(0, 0, 0));
        jTextArea2.setSelectionColor(new java.awt.Color(0, 255, 0));
        jScrollPane2.setViewportView(jTextArea2);

        jScrollPane1.setBorder(javax.swing.BorderFactory.createEmptyBorder(1, 1, 1, 1));

        jTextArea1.setEditable(false);
        jTextArea1.setBackground(new java.awt.Color(0, 0, 0));
        jTextArea1.setColumns(20);
        jTextArea1.setFont(new java.awt.Font("Liberation Mono", 1, 11)); // NOI18N
        jTextArea1.setForeground(new java.awt.Color(255, 255, 255));
        jTextArea1.setLineWrap(true);
        jTextArea1.setRows(5);
        jTextArea1.setWrapStyleWord(true);
        jTextArea1.setBorder(javax.swing.BorderFactory.createEmptyBorder(2, 3, 1, 1));
        jTextArea1.setCursor(new java.awt.Cursor(java.awt.Cursor.DEFAULT_CURSOR));
        jTextArea1.setSelectedTextColor(new java.awt.Color(0, 0, 0));
        jTextArea1.setSelectionColor(new java.awt.Color(0, 255, 0));
        jScrollPane1.setViewportView(jTextArea1);

        jLabel1.setForeground(new java.awt.Color(0, 255, 0));
        jLabel1.setHorizontalAlignment(javax.swing.SwingConstants.CENTER);
        jLabel1.setText("Players");

        jLabel2.setForeground(new java.awt.Color(0, 255, 0));
        jLabel2.setHorizontalAlignment(javax.swing.SwingConstants.CENTER);
        jLabel2.setText("Market");

        jLabel3.setForeground(new java.awt.Color(0, 255, 0));
        jLabel3.setHorizontalAlignment(javax.swing.SwingConstants.CENTER);
        jLabel3.setText("Stocks");

        javax.swing.GroupLayout jPanel1Layout = new javax.swing.GroupLayout(jPanel1);
        jPanel1.setLayout(jPanel1Layout);
        jPanel1Layout.setHorizontalGroup(
            jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel1Layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(jLabel1, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .addComponent(jScrollPane1, javax.swing.GroupLayout.DEFAULT_SIZE, 304, Short.MAX_VALUE))
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(jScrollPane2, javax.swing.GroupLayout.DEFAULT_SIZE, 304, Short.MAX_VALUE)
                    .addComponent(jLabel2, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(jLabel3, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .addComponent(jScrollPane3, javax.swing.GroupLayout.DEFAULT_SIZE, 304, Short.MAX_VALUE))
                .addContainerGap())
        );
        jPanel1Layout.setVerticalGroup(
            jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel1Layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                    .addComponent(jLabel1)
                    .addComponent(jLabel3)
                    .addComponent(jLabel2, javax.swing.GroupLayout.PREFERRED_SIZE, 15, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(jScrollPane1, javax.swing.GroupLayout.Alignment.TRAILING, javax.swing.GroupLayout.DEFAULT_SIZE, 433, Short.MAX_VALUE)
                    .addComponent(jScrollPane3, javax.swing.GroupLayout.Alignment.TRAILING)
                    .addComponent(jScrollPane2))
                .addContainerGap())
        );

        javax.swing.GroupLayout layout = new javax.swing.GroupLayout(finestra.getContentPane());
        finestra.getContentPane().setLayout(layout);
        finestra.getContentPane().setBackground(java.awt.Color.BLACK);
        layout.setHorizontalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addComponent(jPanel1, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                .addContainerGap())
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addComponent(jPanel1, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                .addContainerGap())
        );

        finestra.pack();
    }// </editor-fold>                        

}