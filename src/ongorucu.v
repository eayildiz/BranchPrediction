`timescale 1ns/1ps

`define GUCLU_DEVAM 2'b00
`define ZAYIF_DEVAM 2'b01
`define ZAYIF_ATLAMA 2'b10
`define GUCLU_ATLAMA 2'b11


//Kullanilan yöntem geçmiş tablolu çift doruklu ongorucu.
//Bir geçmiş tablosundan ve tabloyu guncelleyen durum makinasindan olusur.
//NOT: Sadece yorum satiri ekledigim icin tekrardan sentezleme yapmadim. 
module ongorucu(
    input clk,
    input rst,
    input [31:0] getir_ps,
    input [31:0] getir_buyruk,
    input getir_gecerli,
    input [31:0] yurut_ps,
    input [31:0] yurut_buyruk,
    input yurut_dallan,
    input [31:0] yurut_dallan_ps,
    input yurut_gecerli,
    output sonuc_dallan,
    output [31:0] sonuc_dallan_ps
);
    reg [1:0] tahmin_tablosu [0:1023];
    
    reg [31:0] anlik;
    reg tahmin_dallanma_kayit;
    reg [31:0] tahmin_adres_kayit;

    //Tabloyu doldurma
    integer i;
    initial
    begin
        for (i = 0; i < 1024; i = i + 1)
        begin
            tahmin_tablosu[i] = `ZAYIF_DEVAM;
        end
    end

    assign sonuc_dallan = tahmin_dallanma_kayit; 
    assign sonuc_dallan_ps = tahmin_adres_kayit;

    always @(*)
    begin
        if(getir_gecerli)
        begin
            //Anlik degeri al.
            anlik[0] = 1'b0;
            anlik[4:1] = getir_buyruk[11:8];
            anlik[10:5] = getir_buyruk[30:25];
            anlik[11] = getir_buyruk[7];
            if(getir_buyruk[31] == 1'b1)
                anlik[31:12] = 20'b11_111_111_111_111_111_111;
            else
                anlik[31:12] = 20'b00_000_000_000_000_000_000;

            tahmin_adres_kayit = getir_ps + anlik;
            tahmin_dallanma_kayit = !tahmin_tablosu[getir_ps[11:2]][1];
        end
    end

    always @(posedge clk)
    begin
        if(rst)
        begin
            for (i = 0; i < 1024; i = i + 1)
            tahmin_tablosu[i] <= `ZAYIF_DEVAM;
        end
        //Guncelleme
        if(yurut_gecerli)
        begin
            case (tahmin_tablosu[yurut_ps[11:2]])
                2'b00:     //GUCLU_DEVAM
                begin
                    //$display("GUCLU_DEVAM kismina girildi. Deger eski: %b", tahmin_tablosu[yurut_ps[9:0]]);
                    //$display("yurut_ps degeri: %h", yurut_ps[11:2]);
                    if(yurut_dallan)
                    begin
                        //$display("If icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `ZAYIF_DEVAM;
                    end
                    //$display("GUCLU_DEVAM kismina girildi. Deger yeni: %b", tahmin_tablosu[yurut_ps[9:0]]);
                end 
                2'b01:     //ZAYIF_DEVAM
                begin
                    //$display("ZAYIF_DEVAM kismina girildi. Deger eski: %b", tahmin_tablosu[yurut_ps[9:0]]);
                    //$display("yurut_ps degeri: %h", yurut_ps[11:2]);
                    if(yurut_dallan == 1'b1)
                    begin
                        //$display("If icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `GUCLU_ATLAMA;
                    end
                    else
                    begin
                        //$display("else icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `GUCLU_DEVAM;
                    end
                    //$display("ZAYIF_DEVAM kismina girildi. Deger yeni: %b", tahmin_tablosu[yurut_ps[9:0]]);
                end
                2'b10:     //ZAYIF_ATLAMA
                begin
                    //$display("ZAYIF_ATLAMA kismina girildi. Deger eski: %b", tahmin_tablosu[yurut_ps[9:0]]);
                    //$display("yurut_ps degeri: %h", yurut_ps[11:2]);
                    if(yurut_dallan)
                    begin
                        //$display("If icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `GUCLU_ATLAMA;
                    end
                    else
                    begin
                        //$display("else icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `GUCLU_DEVAM;
                    end
                    //$display("ZAYIF_ATLAMA kismina girildi. Deger yeni: %b", tahmin_tablosu[yurut_ps[9:0]]);
                end
                2'b11:     //GUCLU_ATLAMA
                begin
                    //$display("GUCLU_ATLAMA kismina girildi. Deger eski: %b", tahmin_tablosu[yurut_ps[9:0]]);
                    //$display("yurut_ps degeri: %h", yurut_ps[11:2]);
                    if(yurut_dallan == 1'b0)
                    begin
                        //$display("If icinde");
                        tahmin_tablosu[yurut_ps[11:2]] = `ZAYIF_ATLAMA;
                    end
                    //$display("GUCLU_ATLAMA kismina girildi. Deger yeni: %b", tahmin_tablosu[yurut_ps[9:0]]);
                end
                default:
                    $display("Tahmin Tablosu Okumasi Hatasi");
            endcase
        end
    end
endmodule
