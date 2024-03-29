`timescale 1ns / 1ps

//`define DEBUG_EN
`define INFO_EN
//`define DUMP_EN

`define BRANCH_COUNT 20
`define SIM_LEN 20

`define PC_LEN 32
`define INST_LEN 32
`define TKN_LEN 1

`define PC_OFFSET 0
`define PC `PC_OFFSET +: `PC_LEN
`define INST_OFFSET `PC_OFFSET + `PC_LEN
`define INST `INST_OFFSET +: `INST_LEN
`define TKN_OFFSET `INST_OFFSET + `INST_LEN
`define TKN `TKN_OFFSET +: `TKN_LEN
`define TRG_PC_OFFSET `TKN_OFFSET + `TKN_LEN
`define TRG_PC `TRG_PC_OFFSET +: `PC_LEN
`define ENTRY_LEN `TRG_PC_OFFSET + `PC_LEN

module ongoru_cevreleyici ();

   reg [`ENTRY_LEN-1:0] br_info[0:`BRANCH_COUNT-1];
   reg [$clog2(`BRANCH_COUNT * `SIM_LEN):0] count;
   reg [$clog2(`BRANCH_COUNT * `SIM_LEN):0] count_ns;

   reg [$clog2(`BRANCH_COUNT)-1:0] prog_ptr;
   reg [$clog2(`BRANCH_COUNT)-1:0] prog_ptr_ns;

   reg fetch_valid;
   reg fetch_valid_ns;

   reg [`PC_LEN-1:0] predicted_pc;
   reg [`PC_LEN-1:0] predicted_pc_ns;

   reg prediction;
   reg prediction_ns;

   reg prediction_valid;
   reg prediction_valid_ns;

   wire bp_pred;
   wire [31:0] bp_target;

   reg clk;
   reg rstn;

   wire taken_mismatch;
   wire pc_mismatch;
   wire mispredict;
   wire [1:0] tahmin_tablosu_durumu;

   wire ongorulen_dallanma_yonu;
   wire gercek_dallanma_yonu;
   wire [31:0] gercek_hedef_ps;
   wire [31:0] ongorulen_hedef_ps;

   assign taken_mismatch = (gercek_dallanma_yonu !== ongorulen_dallanma_yonu) && prediction_valid;
   assign pc_mismatch = (gercek_hedef_ps !== ongorulen_hedef_ps) && prediction_valid;
   assign mispredict = (taken_mismatch || pc_mismatch) && prediction_valid;
   assign ongorulen_dallanma_yonu = prediction;
   assign ongorulen_hedef_ps = predicted_pc;
   assign gercek_dallanma_yonu = br_info[prog_ptr][`TKN];
   assign gercek_hedef_ps = br_info[prog_ptr][`TRG_PC];
   assign tahmin_tablosu_durumu = ongorucu.tahmin_tablosu[ongorucu.yurut_buyruk[9:0]];

   integer i;
   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         prog_ptr <= 0;
         count <= 0;
         fetch_valid <= 1;
         prediction_valid <= 0;
         prediction <= 0;
         predicted_pc <= 0;
      end else begin
         prog_ptr <= prog_ptr_ns;
         count <= count_ns;
         fetch_valid <= fetch_valid_ns;
         prediction_valid <= prediction_valid_ns;
         prediction <= prediction_ns;
         predicted_pc <= predicted_pc_ns;
      end
   end

   always @* begin
      prog_ptr_ns = prog_ptr;
      count_ns = count;
      prediction_ns = prediction;
      prediction_valid_ns = prediction_valid;
      predicted_pc_ns = predicted_pc;
      fetch_valid_ns = fetch_valid;

      if (!mispredict && prediction_valid) begin
         count_ns = count + 1;
      end

      if (fetch_valid) begin
         fetch_valid_ns = 0;
         prediction_ns  = bp_pred;
         if (bp_pred) begin
            predicted_pc_ns = bp_target;
         end else begin
            predicted_pc_ns = br_info[prog_ptr][`PC] + 4;
         end
         prediction_valid_ns = 1;
      end else begin
         fetch_valid_ns = 1;
         prediction_ns = 0;
         predicted_pc_ns = 0;
         prediction_valid_ns = 0;
         prog_ptr_ns = prog_ptr + 1;
      end
   end

   always begin
      clk = 1;
      #5;
      clk = 0;
      #5;
   end

   initial begin
      for (i = 0; i < `BRANCH_COUNT; i = i + 1) begin
         br_info[i] = 0;
      end
      // MEM DOSYASINA DALLANMA BUYRUGU ICIN SIRASIYLA TARGET PC, TAKEN, INSTRUCTION, PC BILGISI YAZILMALIDIR
      $readmemb("br_info.mem", br_info);
`ifdef INFO_EN
      $display("Branch info dump");
      for (i = 0; i < `BRANCH_COUNT; i = i + 1) begin
         $display("br_info[%0d] PC is %0h", i, br_info[i][`PC]);
         $display("br_info[%0d] INSTRUCTION is %h", i, br_info[i][`INST]);
         $display("br_info[%0d] TAKEN is %0h", i, br_info[i][`TKN]);
         $display("br_info[%0d] TARGET PC is %h\n", i, br_info[i][`TRG_PC]);
      end
`endif
      $display("Starting simulation\n");
`ifdef DUMP_EN
      $dumpfile("ongoru_cevreleyici.vcd");
      $dumpvars(0, ongoru_cevreleyici);
`endif
      rstn = 0;
      repeat (10) @(posedge clk) #2;
      rstn = 1;
      repeat (`SIM_LEN * (`BRANCH_COUNT) * 2) @(posedge clk) #10;
      $display("Simulation finished at %0t ps", $time);
      $display("Prediction accuracy is %0d/%0d", count, `SIM_LEN * (`BRANCH_COUNT));
      #5;
      $finish;
   end

   wire [31:0] update_pc;
   wire [31:0] update_target;
   wire [31:0] update_inst;
   wire update_en;

   assign update_en = prediction_valid && !fetch_valid && rstn;
   assign update_pc = update_en ? br_info[prog_ptr][`PC] : 0;
   assign update_target = update_en ? br_info[prog_ptr][`TRG_PC] : 0;
   assign update_inst = update_en ? br_info[prog_ptr][`INST] : 0;

   ongorucu bp (
      .clk(clk),
      .rst(rstn),
      .getir_ps(br_info[prog_ptr][`PC]),
      .getir_buyruk(br_info[prog_ptr][`INST]),
      .getir_gecerli(fetch_valid && rstn),
      .yurut_ps(update_pc),
      .yurut_buyruk(update_inst),
      .yurut_dallan(br_info[prog_ptr][`TKN]),
      .yurut_dallan_ps(update_target),
      .yurut_gecerli(update_en),
      .sonuc_dallan(bp_pred),
      .sonuc_dallan_ps(bp_target)
   );

endmodule
