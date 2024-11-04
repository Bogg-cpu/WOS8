--Assembler for the custom WOS8 Architecture, Developed by Bogg
--33 instructions of fun, 65k core max as default

--import previous functions that may be useful outside of the VM
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

function  compile(filename, preFileSpace)
  timestart = os.clock()
  local file = io.open(filename, "r")
  if file == nil then
    print("File is empty or not found. Check your file path or contents and try again.")
    return
  end
  local opcodes = {
    NOP = 0,
    ADD = 1,
    SUB = 2,
    MUL = 3,
    DIV = 4,
    INC = 5,
    DEC = 6,
    MOV = 7,
    MLX = 8,
    MLY = 9,
    LOD = 10,
    STO = 11,
    JMP = 12,
    JZ = 13,
    JNZ = 14,
    JC = 15,
    JNC = 16,
    JE = 17,
    JNE = 18,
    MIM = 19,
    AND = 20,
    OR = 21,
    XOR = 22,
    NOT = 23,
    SHL = 24,
    SHR = 25,
    YIR = 26,
    RTI = 27,
    HLI = 28,
    PSH = 29,
    POP = 30,
    HLT = 31,
    CMP = 32,
    MPT = 33,
    COM = 34 --comment instruction, not actually added to the compiled code
  }
  local opcodesmode ={ --used by the assembler to indicate what to put in an instruction word
    NOP = "DRef",
    ADD = "DRef",
    SUB = "DRef",
    MUL = "DRef",
    DIV = "DRef",
    INC = "DRef",
    DEC = "DRef",
    MOV = "DRef",
    MLX = "DRef",
    MLY = "DRef",
    LOD = "DRef",
    STO = "DRef",
    JMP = "2Imm",
    JZ = "2Imm",
    JNZ = "2Imm",
    JC = "2Imm",
    JNC = "2Imm",
    JE = "2Imm",
    JNE = "2Imm",
    MIM = "1Imm",
    AND = "DRef",
    OR = "DRef",
    XOR = "DRef",
    NOT = "DRef",
    SHL = "DRef",
    SHR = "DRef",
    YIR = "DRef",
    RTI = "DRef",
    HLI = "DRef",
    PSH = "DRef",
    POP = "DRef",
    HLT = "2Imm",
    CMP = "DRef",
    MPT = "2Imm",
    COM = "omit" --comment instruction, not actually added to the compiled code
  }
  local compiled = {}
  for i = 1, preFileSpace do
    table.insert(compiled, 0)
  end
  print("pre-file-space allocated.")
  for line in file:lines() do
    local opcode, operand1, operand2 = line:match("(%S+)%s+(%S+)%s+(%S+)")
    if opcode ~= nil and opcodes[opcode] ~= nil then
      if opcodesmode[opcode] == "DRef" then
        table.insert(compiled, opcodes[opcode])
        table.insert(compiled, tostring(operand1))
        table.insert(compiled, tostring(operand2))
      end
      if opcodesmode[opcode] == "1Imm" then
        table.insert(compiled, opcodes[opcode])
        table.insert(compiled, tostring(operand1))
        table.insert(compiled, tonumber(operand2))
      end
      if opcodesmode[opcode] == "2Imm" then
        table.insert(compiled, opcodes[opcode])
        table.insert(compiled, PCtoPCX(tonumber(operand1)))
        table.insert(compiled, PCtoPCY(tonumber(operand2)))
      end
      if opcodesmode[opcode] == "omit" then
        print("omitted")
      end
      else
        print("Invalid instruction: " .. line)
      end
    end
  file:close()
  return compiled
end

function export(compiled)
  local file = io.open("compiled.txt", "w")
  if file == nil then
    print("File not found. Check your file path and try again.")
    return
  end

  file:write("{")

  for i = 1, #compiled do
    if type(compiled[i]) == "string" then
      file:write("\"" .. compiled[i] .. "\"")
    else
      file:write(compiled[i])
    end

    if i ~= #compiled then
      file:write(",")
    end
  end

  file:write("}")

  file:close()
  print("Build complete.")
  timeend = os.clock()
  print("Time taken: " .. timeend - timestart .. " seconds")
end

local compiled = compile("asm.txt", 255) -- Example: pre-file space of 255 zeroes
export(compiled)
