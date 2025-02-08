module uart_tx
  #(
    parameter clock_frequency = 1000000,
    parameter baud_rate = 9600
  )
  (
    input clk, rst,
    input new_data,
    input [7:0] din,
    output reg donetx, tx
  );
  
  // clock parameters
  
  localparam clk_gen = (clock_frequency/baud_rate);
  
  int clk_count = 0;
  reg uart_clk = 0;
  
  // generation of clock
  
  always@(posedge clk) begin
    
    if(rst) begin
      
      clk_count <= 0;
      donetx <= 1'b0;
      tx <= 1'b1;
      
    end
    else begin
      
      if(clk_count<clk_gen/2) begin
        
        clk_count <= clk_count + 1;
        
      end
      else begin
        
        uart_clk <= ~uart_clk;
        clk_count <= 0;
        
      end
      
    end
    
  end
  
  // FSM
  
  typedef enum bit { idle = 1'b0, transmit = 1'b1 } state_type;
  
  state_type state = idle;
  
  reg [7:0] temp;
  
  int counter;
  
  always@(posedge uart_clk) begin
    
    case(state)
      
      idle: begin
        
        if(new_data) begin
          
          temp <= din;
          donetx <= 1'b0;
          tx <= 1'b0;
          state <= transmit;
          counter <= 0;
          
        end
        else begin
          
          state <= idle;
          
        end
        
      end
      
      transmit: begin
        
        if(counter<8) begin
          
          counter <= counter + 1;
          tx <= temp[counter];
          state <= transmit;
          
        end
        else begin
          
          counter <= 0;
          tx <= 1'b1;
          donetx <= 1'b1;
          state <= idle;
          
        end
        
      end
      
    endcase
    
  end
  
endmodule

module uart_rx
  #(
    parameter clock_frequency = 1000000,
    parameter baud_rate = 9600
  )
  (
    input clk, rst,
    input rx,
    output [7:0] dout,
    output reg donerx
  );
  
  // clock parameters
  
  localparam clk_gen = (clock_frequency/baud_rate);
  
  int clk_count = 0;
  reg uart_clk = 0;
  
  always@(posedge clk) begin
    
    if(rst) begin
      
      donerx <= 0;
      clk_count <= 0;
      
    end
    else begin
      
      if(clk_count<clk_gen/2) begin
        
        clk_count <= clk_count + 1;
        
      end
      else begin
        
        uart_clk <= ~uart_clk;
        clk_count <= 0;
        
      end
      
    end
    
  end
  
  // FSM
  
  typedef enum bit { detect = 1'b0, receive = 1'b1 } state_type;
  
  state_type state = detect;
  
  reg [7:0] temp;
  
  int count = 0;
  
  always@(posedge uart_clk) begin
    
    case(state)
      
      detect: begin
        
        if(!rx) begin
          
          state <= receive;
          donerx <= 0;
          temp <= 0;
          count <= 0;
          
        end
        else begin
          
          state <= detect;
          
        end
        
      end
      
      receive: begin
        
        if(count<8) begin
          
          temp <= {rx, temp[7:1]};
          state <= receive;
          count <= count + 1;
          
        end
        else begin
          
          state <= detect;
          donerx <= 1'b1;
          count <= 0;
          
        end
        
      end
      
    endcase
    
  end
  
  assign dout = temp;
  
endmodule

module top
  #(
    parameter clock_frequency = 1000000,
    parameter baud_rate = 9600
  )
  (
    input clk, rst,
    input new_data, rx,
    input [7:0] din,
    output tx, donetx, donerx,
    output [7:0] dout
  );
  
  uart_tx d1(.clk(clk), .rst(rst), .new_data(new_data), .din(din), .tx(tx), .donetx(donetx));
  uart_rx d2(.clk(clk), .rst(rst), .rx(rx), .donerx(donerx), .dout(dout));
  
endmodule

interface uart_intf;
  
  logic clk, rst;
  logic new_data;
  logic [7:0] din;
  logic donetx, tx;
  logic rx;
  logic donerx;
  logic [7:0] dout;
  
  logic clktx, clkrx;
  
endinterface
