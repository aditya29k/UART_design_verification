class transaction;
  
  typedef enum bit { trans = 1'b0, receive = 1'b1 } oper_type;
  rand oper_type oper;
  
  rand bit new_data;
  rand bit [7:0] din;
  bit donetx, tx;
  bit rx, donerx;
  bit [7:0] dout;
  
  function void display_tx(string tag);
    
    $display("[%0s] din: %0d, donetx: %0d, tx: %0d", tag, din, donetx, tx);
    
  endfunction
  
  function void display_rx(string tag);
    
    $display("[%0s] rx: %0d, dout: %0d, donerx: %0d", tag, rx, dout, donerx);
    
  endfunction
  
  function transaction copy();
    
    copy = new();
    copy.oper = this.oper;
    copy.new_data = this.new_data;
    copy.din = this.din;
    copy.donetx = this.donetx;
    copy.tx = this.tx;
    copy.rx = this.rx;
    copy.donerx = this.donerx;
    copy.dout = this.dout;
    
  endfunction
  
  constraint oper_cons { oper dist { 0 := 80, 1 := 20 }; }
  
  constraint new_data_cons { new_data dist {1 := 10, 0 := 0}; }
  
  constraint din_cons { new_data == 0 -> din == 0; }
  
endclass

class generator;
  
  transaction t;
  mailbox #(transaction) mbx;
  
  int count;
  
  event parnext;
  
  event done;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    t = new();
    
  endfunction
  
  task run();
    
    repeat(count) begin
      
      $display("--------------------------------");
      assert(t.randomize()) else $display("[GEN] RABDOMIZATION FAILED");
      mbx.put(t.copy());
      $display("[GEN] oper: %0d, new_data: %0d, din: %0d, rx: %0d", t.oper, t.new_data, t.din, t.rx);
      @(parnext);
      
    end
    
    ->done;
    
  endtask
  
endclass

class driver;
  
  transaction t;
  
  mailbox #(transaction) mbx;
  mailbox #(bit [7:0]) reff;
  
  virtual uart_intf intf;
  
  bit [7:0] temp;
  
  //event parnext;
  
  function new(mailbox #(transaction) mbx, mailbox #(bit [7:0]) reff);
    
    this.mbx = mbx;
    this.reff = reff;
    
  endfunction
  
  task reset();
    
    intf.rst <= 1'b1;
    intf.new_data <= 1'b0;
    intf.din <= 0;
    intf.rx <= 1'b1;
    repeat(5)@(posedge intf.clk);
    intf.rst <= 1'b0;
    @(posedge intf.clk);
    $display("[DRV] SYSTEM RESETTED");
    $display("--------------------------------");
    
  endtask
  
  task run();
    
    forever begin
      
      mbx.get(t);
      if(t.oper == 1'b0) begin
        intf.new_data <= t.new_data;
        intf.din <= t.din;
        intf.rx <= 1'b1;
        reff.put(t.din);
        @(posedge intf.clktx);
        @(posedge intf.donetx);
        intf.new_data <= 1'b0;
        t.display_tx("DRV");
        @(posedge intf.clktx);
        //->parnext;
        
      end
      else begin
        
        intf.rx <= 1'b0;
        intf.new_data <= 1'b0;
        intf.din <= 0;
        @(posedge intf.clkrx);
        for(int i = 0; i<8; i++ ) begin
          
          @(posedge intf.clkrx);
          intf.rx <= $urandom;
          temp = {intf.rx, temp[7:1]};
          
        end
        reff.put(temp);
        intf.rx <= 1'b1;
        @(posedge intf.donerx);
        $display("[DRV] temp: %0d", temp);
        @(posedge intf.clkrx);
        //->parnext;
        
      end
      
    end
    
  endtask
  
endclass

class monitor;
  
  transaction t;
  
  mailbox #(bit [7:0]) mbx;
  
  virtual uart_intf intf;
  
  bit [7:0] temp;
  
  //event parnext;
  
  function new(mailbox #(bit [7:0]) mbx);
    
    this.mbx = mbx;
    t = new();
    
  endfunction
  
  task run();
    
    forever begin
      
      @(posedge intf.clktx);
      if(intf.new_data == 1'b1 && intf.rx == 1'b1) begin
        
        @(posedge intf.donetx);
        repeat(3)@(posedge intf.clktx);
        for(int i = 0; i<8; i++) begin
          
          @(posedge intf.clktx);
          t.tx = intf.din[i];
          temp[i] = t.tx;
          
        end
        mbx.put(temp);
        $display("[MON] TRANSMITTED VALUE: %0d", temp);
        @(posedge intf.clktx);
        //->parnext;
        
      end
      else if(intf.new_data == 1'b0 && intf.rx == 1'b0) begin
        
        @(posedge intf.donerx);
        t.dout = intf.dout;
        @(posedge intf.clkrx);
        $display("[MON] RECEIVED VALUE: %0d", t.dout);
        mbx.put(t.dout);
        //->parnext;
        
      end
      
    end
    
  endtask
  
endclass

class scoreboard;
  
  mailbox #(bit [7:0]) mbx;
  mailbox #(bit [7:0]) reff;
  
  bit [7:0] arr_main, arr_reff;
  
  event parnext;
  
  function new( mailbox #(bit [7:0]) mbx, mailbox #(bit [7:0]) reff );
    
    this.mbx = mbx;
    this.reff = reff;
    
  endfunction
  
  task run();
    
    forever begin
      
      mbx.get(arr_main);
      reff.get(arr_reff);
      if(arr_main == arr_reff) begin
        
        $display("[SCO] DATA MATCHED");
        
      end
      else begin
        
        $display("[SCO] DATA MISMATCHED");
        
      end
      
      $display("---------------------------");
      ->parnext;
      
    end
    
  endtask
  
endclass

class environment;
  
  transaction t;
  generator g;
  driver d;
  monitor m;
  scoreboard s;
  
  mailbox #(transaction) mbx;
  mailbox #(bit [7:0]) reff;
  mailbox #(bit [7:0]) mbx_ms;
   
  event done;
  event parnext;
  
  virtual uart_intf intf;
  
  function new(virtual uart_intf intf);
    
    mbx = new();
    reff = new();
    mbx_ms = new();
    
    t = new();
    g = new(mbx);
    d = new(mbx, reff);
    m = new(mbx_ms);
    s = new(mbx_ms, reff);
    
    this.intf = intf;
    d.intf = this.intf;
    m.intf = this.intf;
    
    g.done = done;
    g.parnext = s.parnext;
    
  endfunction
  
  task pre_test();
    
    d.reset();
    
  endtask
  
  task test();
    
    fork
      
      g.run();
      d.run();
      m.run();
      s.run();
      
    join_any
    
  endtask
  
  task post_test();
    
    wait(done.triggered);
    $finish();
    
  endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask
    
endclass

module tb;
  
  environment env;
  
  uart_intf intf();
  
  top #(1000000, 9600) DUT(.clk(intf.clk), .rst(intf.rst), .new_data(intf.new_data), .din(intf.din), .tx(intf.tx), .donetx(intf.donetx), .rx(intf.rx), .donerx(intf.donerx), .dout(intf.dout));
  
  initial begin
    
    intf.clk <= 0;
    
  end
  
  always #10 intf.clk <= ~intf.clk;
  
  assign intf.clktx = DUT.d1.uart_clk;
  assign intf.clkrx = DUT.d2.uart_clk;
  
  initial begin
    
    env = new(intf);
    env.g.count = 15;
    env.run();
    
  end
  
  initial begin
  
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end
  
endmodule
