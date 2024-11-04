  -- Simulation specific parameters
  Running = true --don't touch or else the VM will never start!
  iteration = 0
  verbose = true -- verbose dumps the registers every iteration
  flagverbose = true -- verbose dumps the flags every iteration
  stackVerbose = true -- verbose dumps the stack (MLX 1 - 255 MLY 0) every iteration
  ramVerbose = true -- verbose dumps the ram every iteration

  delay = 0 -- delay in (unknown) between each iteration

  -- CPU virtual modules (RAM, ROM, etc.)
  RAM = {}
  IRQvector = {
  0,--Reserved
  1 --When keyboard data is available
  }
  -- Registers stored in a table
  Registers = {
    A = 0,
    B = 0,
    C = 0,
    D = 0,
    E = 0,
    MX = 0, -- Memory X
    MY = 0, -- Memory Y
    --used with MLX and MLY to set the coordinates of the next RAM array address
    PC = 0,
    PCX = 0, -- Program Counter X
    PCY = 0, -- Program Counter Y
    --upgraded from PC to PCX/Y (PC is still used to calulate RAM array's address)
    SP = 0,  -- Stack Pointer
    IRR = 0 -- Interrupt Request Register (Stores the ID of the interrupt to jump to a specific handler) 
  }

  -- Shadow registers, for when the CPU is in an interrupt
  ShadowRegisters = {
    A = 0,
    B = 0,
    C = 0,
    D = 0,
    E = 0,
    MX = 0,
    MY = 0,
    PCX = 0,
    PCY = 0
    --SP is not shadowed because stack must not be desynchronized
    --IRR is not shadowed because that would defeat the purpose of the interrupt being cleared after restoring the registers, leading to an infinite loop
  }

  -- IO flags for the interrupt system. This includes IRQ flag, and the CPU's SND (Send) flag
  IO = {
    Send = false, --this is the send flag, which tells the peripheral the CPU is ready to accept data
    Conf = false --this is the confirm flag, which tells the peripheral that the CPU got the data, and the interrupt has been handled and cleared
  }

  -- Flags
  Flags = {
    ZF = false,
    CF = false,
    EF = false,
    ON = true,
  }

  function ReadFileToArray(filename)
    local file = io.open(filename, "r") -- Open the file in read mode
    local array = {}

    if file then
      print(string.format("Reading file %s", filename,"..."))
      for line in file:lines() do
        table.insert(array, line) -- Add each line of the file to the array
      end
      file:close() -- Close the file
      print("File read.")
    else
      print("Failed to open file: " .. filename)
    end

    return array
  end

  function DumpReg()
    if verbose then
      --list all registers and shadow registers in a side by side table after every instruction
      print("Registers for Iteration", iteration)
      print("    Reg/SReg")
      print("PCX: ",Registers.PCX)
      print("PCY: ",Registers.PCY)
      print("SP: ",Registers.SP)
      print("instruction: ",((Registers.PC+3)/3))
      print("PC (for RAM array):",Registers.PC)
      print("A: ",Registers.A .. "      " .. ShadowRegisters.A)
      print("B: ",Registers.B .. "      " .. ShadowRegisters.B)
      print("C: ",Registers.C .. "      " .. ShadowRegisters.C)
      print("D: ",Registers.D .. "      " .. ShadowRegisters.D)
      print("E: ",Registers.E .. "      " .. ShadowRegisters.E)
      print("MX:",Registers.MX .. "      " .. ShadowRegisters.MX)
      print("MY:",Registers.MY .. "      " .. ShadowRegisters.MY)
      print("----------------------")
    end
  end
  function DumpFlags()
    if flagverbose then
      --list all flags in a side by side table after every instruction
      print("Flags for Iteration", iteration)
      print("Z:",Flags.ZF)
      print("C:",Flags.CF)
      print("E:",Flags.EF)
      print("O:",Flags.ON)
      print("----------------------")
    end
  end


  function DumpStack(force)
    if stackVerbose or force then
      --list the stack after every instruction
      print("Stack for Iteration", iteration)
      print("    Stack")
      for i = 0, 255 do
        print(i,":",RAM[i])
      end
    end
  end
  function CoreDump()
    if ramVerbose then
      --list the ram after every instruction
      print("RAM for Iteration", iteration)
      print("    RAM")
      for i = (Registers.PC-8),(Registers.PC+32) do
        if i > 0 then
          if RAM[i] ~= nil then
            if (Registers.PC+1) == i then
              io.write("PC->")
              io.flush()
            elseif (Registers.SP+1) == i then
                io.write("SP->")
                io.flush()
            elseif (Registers.MX*Registers.MY+1) == i then
                io.write("CM->") --Core Memory
                io.flush()
            else
              io.write("    ")
              io.flush()
            end
            print(i,":",RAM[i])
          end
          end
      end
    end
  end
  function FullCoreDump()
    if true then
      --list the ram after every instruction
      print("RAM for Iteration", iteration)
      print("    RAM")
      for i = 0, #RAM do
        if i > 0 then
          if RAM[i] ~= nil then
            if (Registers.PC+1) == i then
              io.write("PC->")
              io.flush()
            elseif (Registers.SP+1) == i then
                io.write("SP->")
                io.flush()
            elseif (Registers.MX*Registers.MY+1) == i then
                io.write("CM->") --Core Memory
                io.flush()
            else
              io.write("    ")
              io.flush()
            end
            print(i,":",RAM[i])
          end
          end
      end
    end
  end
  --PCX/PCY relationship functions
  function PCtoPCX(PC)
    local PCX = PC % 256
    return PCX
  end

  function PCtoPCY(PC)
    local PCY = math.floor(PC / 256)
    return PCY
  end

  function PCXYtoPC(PCX, PCY)
    PCX = PCX % 256
    PCY = PCY % 256
    local PC = PCY * 256 + PCX
    return PC
  end

  -- Opcode if-statement block
  function Execute(opcode, source, target)

    if opcode == 0 then
      --print("NOP")

    elseif opcode == 1 then
      --print("ADD")
      Registers[target] = Registers[source] + Registers[target]
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end

    elseif opcode == 2 then
      --print("SUB")
      Registers[target] = Registers[source] - Registers[target]
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end

    elseif opcode == 3 then
      --print("MUL")
      Registers[target] = Registers[source] * Registers[target]
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end


    elseif opcode == 4 then
      --print("DIV")
      Registers[target] = Registers[source] / Registers[target]
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end


    elseif opcode == 5 then
      --print("INC")
      Registers[target] = Registers[source] + 1
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end


    elseif opcode == 6 then
      --print("DEC")
      Registers[target] = Registers[source] - 1
      if Registers[target] == 0 then -- check for zero flag
        Flags.ZF = true
      else
        Flags.ZF = false
      end
      if Registers[target] >= 255 then -- check for overflow (and handle it)
        Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
        Flags.CF = true
      else
        Flags.CF = false
      end


    elseif opcode == 7 then
      --print("MOV")
      Registers[target] = Registers[source]

    elseif opcode == 8 then
      --print("MLX")
      Registers.MX = Registers[source]

    elseif opcode == 9 then
      --print("MLY")
      Registers.MY = Registers[source]

    elseif opcode == 10 then
      --print("LOD")
      local memoryAddress = Registers.MY * 256 + Registers.MX
      Registers[source] = RAM[memoryAddress] --source is used here instead of target since only one operand is used

    elseif opcode == 11 then
      --print("STO")
      local memoryAddress = Registers.MY * 256 + Registers.MX
      RAM[memoryAddress] = Registers[source]

    elseif opcode == 12 then
      --print("JMP")
      Registers.PCX = source
      Registers.PCY = target

    elseif opcode == 13 then
      --print("JZ")
      if Flags.ZF == true then
        Registers.PCX = source
        Registers.PCY = target
      end
      elseif opcode == 14 then
        --print("JNZ")
        if Flags.ZF == false then
          Registers.PCX = source
          Registers.PCY = target
        end

      elseif opcode == 15 then
        --print("JC")
        if Flags.CF == true then
          Registers.PCX = source
          Registers.PCY = target
        end

      elseif opcode == 16 then
        --print("JNC")
        if Flags.CF == false then
          Registers.PCX = source
          Registers.PCY = target
        end

      elseif opcode == 17 then
        --print("JE")
        if Flags.EF == true then
          Registers.PCX = source
          Registers.PCY = target
        end

      elseif opcode == 18 then
        --print("JNE")
        if Flags.EF == false then
          Registers.PCX = source
          Registers.PCY = target
        end

      elseif opcode == 19 then
        --print("MIM") --Move Immediate (basically creates a value from nothing)
        Registers[target] = tonumber(source) --not Registers[source] because source is a number, not referring to a register

      elseif opcode == 20 then
        --print("AND")
        Registers[target] = Registers[source] and Registers[target]

      elseif opcode == 21 then
        --print("OR")
        Registers[target] = Registers[source] or Registers[target]

      elseif opcode == 22 then
        --print("XOR")
        Registers[target] = not (Registers[source] and not Registers[target]) or (Registers[source] and not Registers[target]) or not Registers[source] and Registers[target] -- yucky logical gibberish

      elseif opcode == 23 then
        --print("NOT")
        Registers[target] = not Registers[source]

      elseif opcode == 24 then
        --print("SHL")
        Registers[source] = Registers[source] * 2

      elseif opcode == 25 then
        --print("SHR")
        Registers[source] = math.floor(Registers[source] / 2)

      elseif opcode == 26 then
        --print("YIR") -- Yield Interrupt Request
        if Registers.IRR ~= 0 then
          --capture the current state of the system registers to shadow
          ShadowRegisters.A = Registers.A
          ShadowRegisters.B = Registers.B
          ShadowRegisters.C = Registers.C
          ShadowRegisters.D = Registers.D
          ShadowRegisters.E = Registers.E
          ShadowRegisters.MX = Registers.MX --store the Memory Access
          ShadowRegisters.MY = Registers.MY
          ShadowRegisters.PCX = Registers.PCX --store the Program Counter
          ShadowRegisters.PCY = Registers.PCY
          --go to 960 + 300*IRR - 300 (IRR 1 is 960, IRR 2 is 960+300, IRR 3 is 960+600, etc)
          Registers.PC = 960 + 300 * Registers.IRR - 300
        end
      elseif opcode == 27 then
        --print("RTI") --Return from Interrupt
        --restore the state of the system registers from shadow
        Registers.A = ShadowRegisters.A
        Registers.B = ShadowRegisters.B
        Registers.C = ShadowRegisters.C
        Registers.D = ShadowRegisters.D
        Registers.E = ShadowRegisters.E
        Registers.MX = ShadowRegisters.MX
        Registers.MY = ShadowRegisters.MY
        Registers.PCX = ShadowRegisters.PCX
        Registers.PCY = ShadowRegisters.PCY
        Registers.PC = PCXYtoPC(Registers.PCX, Registers.PCY) --jump to pre-interrupt PC
        Registers.IRR = 0 -- clear the IRR flag
      elseif opcode == 28 then
        --print("HLI") --Halt until Interrupt
        --capture the current state of the system registers to shadow
        ShadowRegisters.A = Registers.A
        ShadowRegisters.B = Registers.B
        ShadowRegisters.C = Registers.C
        ShadowRegisters.D = Registers.D
        ShadowRegisters.E = Registers.E
        ShadowRegisters.MX = Registers.MX --store the Memory Access
        ShadowRegisters.MY = Registers.MY
        ShadowRegisters.PCX = Registers.PCX --store the Program Counter
        ShadowRegisters.PCY = Registers.PCY
        if Registers.IRR == 1 then
        --Keyboard IRQ, jump to Keyboard's IRQ handler, at IRQvector[1]
          Registers.PC = IRQvector[1]
          Registers.PCX = PCtoPCX(Registers.PC)
          Registers.PCY = PCtoPCY(Registers.PC)
        else
          --print("No IRQ at this time")
        end
      elseif opcode == 29 then
        --print("PSH")
        RAM[Registers.SP] = (Registers[source])
        Registers.SP = Registers.SP + 1
      elseif opcode == 30 then
        --print("POP")
        Registers[source] = RAM[Registers.SP]
        Registers.SP = Registers.SP - 1
      elseif opcode == 31 then
        --print("HLT")
        --print("Halted")
        Running = false
      elseif opcode == 32 then
        --print("CMP")
        if Registers[source] == Registers[target] then
          Flags.EF = true
        else
          Flags.EF = false
        end
      elseif opcode == 33 then
        --print("MPT")
        print(Registers[source])
        print(Registers[target])
        Registers.MX = Registers[source]
        Registers.MY = Registers[target]
      else do
        print("ERR: Unknown opcode:", opcode)
        for i=1,1000000 do end
      end

    -- if Registers[target] >= 255 then -- check for overflow (and handle it)
    --   Registers[target] = Registers[target] % 256 -- modulo to emulate overflow
    --   Flags.CF = true
    -- else
    --   Flags.CF = false
    -- end

    -- if Registers[target] == 0 then -- check for zero flag
    --   Flags.ZF = true
    -- else
    --   Flags.ZF = false
    -- end

    end
  end

  --Function that runs the control loop
  function Run()
    while Running do
      DumpReg()
      DumpFlags()
      DumpStack()
      CoreDump()
      Registers.PC = PCXYtoPC(Registers.PCX, Registers.PCY)
      local opcode = RAM[Registers.PC+1]
      local source = RAM[Registers.PC+2]
      local target = RAM[Registers.PC+3]
      Execute(opcode, source, target)
      if Registers.PCX + 3 > 255 then
        Registers.PCY = Registers.PCY + math.floor((Registers.PCX + 3) / 256)
        Registers.PCX = (Registers.PCX + 3) % 256
      else
        Registers.PCX = Registers.PCX + 3
      end
      iteration = iteration + 1 -- track the time the CPU has run (in cycles since lua has no concept of time)
      --delay by some amount of time by for-loop trapping
      for i = 1, delay do end
    end
  end

  --Registers.PCX = 255 --skip the stack

  RAM = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,"E",128,33,15,0,11,"E","0",31,0,0}

  verbose = false -- verbose dumps the registers every iteration
  flagverbose = false -- verbose dumps the flags every iteration
  stackVerbose = false -- verbose dumps the stack (MLX 1 - 255 MLY 0) every iteration
  ramVerbose = false -- verbose dumps the ram every iteration

  delay = 1000000 -- delay the CPU by some amount of time (unknown how long really)

  timebefore = os.clock()
  Run()
  timeafter = os.clock()
  FullCoreDump()
  print("Time taken: " .. timeafter - timebefore .. " seconds")
  print("Iterations to halt: ".. iteration .. " iterations")
  while true do
    os.exit(0)
  end --os.exit breaks replit at times
