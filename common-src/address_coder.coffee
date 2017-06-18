# Private network addresses
#  From http://www.duxcw.com/faq/network/privip.htm
#
# 10.0.0.0 - 10.255.255.255
# 172.16.0.0 - 172.31.255.255
# 192.168.0.0 - 192.168.255.255

class IPAddressEncoder

  kDefaultPort = "20116"

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->
    # Our symbols: 26 + 26 + 10 = 62 in total
    # A..Z, a..z, 0..9, @, &

    @symbols = []
    @base = null

    # Don't use L, l, I, O, 1, or zero since, as Mr F has pointed out, these can be hard to distinguish from each other
    this.addSymbols('A', 'H')
    this.addSymbols('J', 'K')
    this.addSymbols('M', 'N')
    this.addSymbols('P', 'Z')
    this.addSymbols('a', 'k')    
    this.addSymbols('m', 'z')
    this.addSymbols('2', '9')
    this.addSymbols('@', '@')
    this.addSymbols('&', '&')
    this.addSymbols('$', '$')
    this.addSymbols('(', '(')
    this.addSymbols(')', ')')
    this.addSymbols('!', '!')
    this.addSymbols('?', '?')
    this.addSymbols(';', ';')

    this.computeBase()

  # ----------------------------------------------------------------------------------------------------------------
  addSymbols: (start, end)->

    @symbols.push {start:start, end:end}

  # ----------------------------------------------------------------------------------------------------------------
  computeBase: ()->

    base = 0

    for s in @symbols
      base += ((s.end).charCodeAt() - (s.start).charCodeAt()) + 1

    @base = base

  # ----------------------------------------------------------------------------------------------------------------
  getBase: ()-> @base

  # ----------------------------------------------------------------------------------------------------------------
  computeMask: (numBits)->

    mask = 0

    for i in [1..numBits]
      mask += Math.pow(2, i-1)
 
    mask

  # ----------------------------------------------------------------------------------------------------------------
  encodeIntIntoBits: (i, numBits)->

    bits = []

    # mask off those bits that we won't be encoding
    value = i & this.computeMask(numBits)

    # march through each bit position, testing for 1 or 0
    # We start with most significant bit
    for n in [numBits..1]
      bit = value & Math.pow(2, n-1)
      flag = if bit is 0 then 0 else 1
     # alert bit + " " + flag
      bits.push flag

    bits    

  # ----------------------------------------------------------------------------------------------------------------
  numBitsPerSymbol: ()->

    numBits = 1

    while (Math.pow(2, numBits) <= @base)
      numBits++

    numBits-1

  # ----------------------------------------------------------------------------------------------------------------
  # Encode bits, left-justified, into chars; the first bit will
  # be represented in the most significant bit of the leftmost char.
  # We may have some space left over, in the rightmost char
  # Returns the encoded char and an array of unused bits
  encodeBitsIntoSymbol: (bits)->

    n = this.numBitsPerSymbol()
    value = 0

    while (n isnt 0) and (bits.length isnt 0)

      bit = bits.shift()

      value += bit << (n-1)

      #alert "n=#{n} value=#{value} #bits remaining=#{bits.length}"

      n--

    {symbol: this.makeSymbolFromInt(value), bits:bits}

  # ----------------------------------------------------------------------------------------------------------------
  encodeBitsIntoSymbols: (bits)->

    out = ""

    while bits.length isnt 0
      result = this.encodeBitsIntoSymbol(bits)
      out += result.symbol
      bits = result.bits

    out

  # ----------------------------------------------------------------------------------------------------------------
  makeSymbolFromInt: (value)->

    i = 0

    for s in @symbols
      c = (s.start).charCodeAt()
      while c <= (s.end).charCodeAt()
        #alert "value=#{value} i=#{i} char=#{String.fromCharCode(c)}"
        if i is value
          return String.fromCharCode(c)
        i++
        c++
              
    null

  # ----------------------------------------------------------------------------------------------------------------    
  decodeSymbolsIntoBits: (symbols)->

    results = []

    for s in symbols
      this.appendBits(results, this.decodeSymbolIntoBits(s))

    results

  # ----------------------------------------------------------------------------------------------------------------
  decodeSymbolIntoBits: (symbol)->

    bits = []

    value = this.getIntFromSymbol(symbol)

    for i in [this.numBitsPerSymbol()..1]
      bit = (value >> (i-1)) & 1
      bits.push bit
      #alert "char=#{symbol} value=#{value} i=#{i} bit=#{bit}"

    bits

  # ----------------------------------------------------------------------------------------------------------------
  getIntFromSymbol: (symbol)->

    result = 0
    i = 0

    for syms in @symbols
      c = (syms.start).charCodeAt()
      while c <= (syms.end).charCodeAt()
        #alert "symbol=#{symbol} c=#{String.fromCharCode(c)} i=#{i}"
        if String.fromCharCode(c) is symbol
          return i
        i++
        c++

    result

  # ----------------------------------------------------------------------------------------------------------------    
  decodeBitsIntoInt: (bits, numBits)->

    value = 0

    n = numBits
    i = 0
    while n isnt 0
      bit = bits.shift()
      value += bit << (n-1) 
      #alert "bit=#{bit} value=#{value} n=#{n} i=#{i} bits=#{bits.length}"     
      n--
      i++
    value

  # ----------------------------------------------------------------------------------------------------------------
  appendBits: (target, bitArray)->

    for b in bitArray
      target.push b

    target

  # ----------------------------------------------------------------------------------------------------------------
  parseIP: (text)->

    text.split(".")

#++++++++++
# 192.168.0.0 - 192.168.255.255
  encode192: (a2, a3, a4)->

    bits = []
 
    # a2 is always 168

    # a3 is nearly always 1, so let's optimize for that
    # Bit #3 (0-based) is 1 if a3 is 1, 0 otherwise
    this.appendBits(bits, this.encodeIntIntoBits(a3 is "1",1))

    # if a3 is not 1, spend 8 bits on it
    if a3 isnt "1"
      this.appendBits(bits, this.encodeIntIntoBits(a3,8))

    # a4 is 0..255
    this.appendBits(bits, this.encodeIntIntoBits(a4, 8))

    bits    

  decode192: (bits)->

    ip="192.168."

    # if bit 2 is 0, then a3 is something other than "1"
    if this.decodeBitsIntoInt(bits, 1)
      ip += "1"
    else
      ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."

    # Next 8 bits are the fourth portion of the address
    ip += this.decodeBitsIntoInt(bits, 8)

    ip

#++++++++++
# 172.16.0.0 - 172.31.255.255
  encode172: (a2, a3, a4)->

    bits = []
 
    # Encode a2, spanning 16..31, in 4 bits
    this.appendBits(bits, this.encodeIntIntoBits(a2-16,4))

    # a3 is 0..255
    this.appendBits(bits, this.encodeIntIntoBits(a3, 8))

    # a4 is 0..255
    this.appendBits(bits, this.encodeIntIntoBits(a4, 8))

    bits    

  decode172: (bits)->

    ip="172."

    ip += (this.decodeBitsIntoInt(bits, 4) + 16)
    ip += "."

    # Next 16 bits are the third and fourth portions of the address
    ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."
    ip += this.decodeBitsIntoInt(bits, 8)

    ip

# 10.0.0.0 - 10.255.255.255
  encode10: (a2, a3, a4)->

    bits = []
 
    this.appendBits(bits, this.encodeIntIntoBits(a2, 8))
    this.appendBits(bits, this.encodeIntIntoBits(a3, 8))
    this.appendBits(bits, this.encodeIntIntoBits(a4, 8))

    bits    

  decode10: (bits)->

    ip="10."

    ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."
    ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."
    ip += this.decodeBitsIntoInt(bits, 8)

    ip

  encodeOther: (a2, a3, a4)->

    bits = []
 
    this.appendBits(bits, this.encodeIntIntoBits(a2, 8))
    this.appendBits(bits, this.encodeIntIntoBits(a3, 8))
    this.appendBits(bits, this.encodeIntIntoBits(a4, 8))

    bits    

  decodeOther: (bits)->

    ip="10."

    ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."
    ip += this.decodeBitsIntoInt(bits, 8)
    ip += "."
    ip += this.decodeBitsIntoInt(bits, 8)

    ip

#++++++++++
  test192: ()->

    this.output "Running 192 test..."

    port = "12345"
    numTests = 0

    for a3 in [0..255]
      for a4 in [0..255]
        addr = "192.168.#{a3}.#{a4}"
        coded = this.encode(addr, port)
        decoded = this.decode(coded)
        numTests++
        if addr + ":" + port isnt decoded
          this.output "ERROR: #{addr} #{decoded}"

    this.output "192 Test done: #{numTests} Completed, Expected #{256*256}"

  test172: ()->

    this.output "Running 172 test..."

    port = "12345"
    numTests = 0

    for a2 in [16..31]
      for a3 in [0..255]
        for a4 in [0..255]
          addr = "172.#{a2}.#{a3}.#{a4}"
          coded = this.encode(addr, port)
          decoded = this.decode(coded)
          numTests++
          if addr + ":" + port isnt decoded
            this.output "ERROR: #{addr} #{decoded}"

    this.output "172 Test done: #{numTests} Completed, Expected #{16*256*256}"

  test10: ()->

    this.output "Running 10 test..."

    port = "12345"
    numTests = 0

    for a2 in [0..255]
      for a3 in [0..255]
        for a4 in [0..255]
          addr = "10.#{a2}.#{a3}.#{a4}"
          coded = this.encode(addr, port)
          decoded = this.decode(coded)
          numTests++
          if addr + ":" + port isnt decoded
            this.output "ERROR: #{addr} #{decoded}"

    this.output "10 Test done: #{numTests} Completed, Expected #{256*256*256}"
  
  testPort: ()->

    this.output "Running Port test..."

    addr = "192.168.1.1"
    numTests = 0

    for port in [0..99999]
        coded = this.encode(addr, port)
        decoded = this.decode(coded)
        numTests++
        if addr + ":" + port isnt decoded
          this.output "ERROR: #{addr} #{decoded}"

    this.output "Port Test done: #{numTests} Completed, Expected #{100000}"

#++++++++++
# Private network addresses
#  From http://www.duxcw.com/faq/network/privip.htm
#
# 10.0.0.0 - 10.255.255.255
# 172.16.0.0 - 172.31.255.255
# 192.168.0.0 - 192.168.255.255

  # ----------------------------------------------------------------------------------------------------------------
  isPrivateAddress: (ip)->

    isPrivate = false

    addrs = (parseInt(a) for a in this.parseIP(ip))

    isPrivate = switch addrs[0]
      when 10 # 10.0.0.0 - 10.255.255.255
        (0 <= addrs[1] <= 255) and (0 <= addrs[2] <= 255) and (0 <= addrs[3] <= 255)
      when 172 # 172.16.0.0 - 172.31.255.255
        (16 <= addrs[1] <= 31) and (0 <= addrs[2] <= 255) and (0 <= addrs[3] <= 255)
      when 192 # 192.168.0.0 - 192.168.255.255
        (addrs[1] is 168) and (0 <= addrs[2] <= 255) and (0 <= addrs[3] <= 255)
      else
        false

    return isPrivate

  # ----------------------------------------------------------------------------------------------------------------
  encode: (ip, port)->

    bits = []
    scheme = null
    symbols = null

    if ip? and this.isPrivateAddress(ip)

      addrs = this.parseIP(ip)

      scheme = null
      switch addrs[0]
        when "192"
          scheme = 0
          remainingBits = this.encode192(addrs[1], addrs[2], addrs[3])
        when "172"
          scheme = 1
          remainingBits = this.encode172(addrs[1], addrs[2], addrs[3])
        when "10"
          scheme = 2
          remainingBits = this.encode10(addrs[1], addrs[2], addrs[3])
        else
          # Apparently has a public address, which we don't support
          null

      if scheme?
        this.appendBits(bits, this.encodeIntIntoBits(scheme, 2))
        this.appendBits(bits, remainingBits)

        if not port? or port isnt kDefaultPort
          this.appendBits(bits, this.encodeIntIntoBits(parseInt(port), 17))

        symbols = this.encodeBitsIntoSymbols(bits)

    symbols

  # ----------------------------------------------------------------------------------------------------------------
  decode: (symbols)->

    bits = this.decodeSymbolsIntoBits(symbols)

    scheme = this.decodeBitsIntoInt(bits, 2)

    ip = switch scheme
      when 0
        this.decode192(bits)
      when 1
        this.decode172(bits)
      when 2
        this.decode10(bits)
      when 3
        this.decodeOther(bits)
      else
        this.decodeOther(bits)
      
    port = kDefaultPort
    if bits.length >= 17
      port = this.decodeBitsIntoInt(bits, 17)

    ip += ":#{port}"
    
    ip

# ==================================================================================================================

# assign to two global namespaces, since this is shared between app and web code bases:

if not Hyperbotic.Network?
  Hyperbotic.Network = {}

Hyperbotic.Network.IPAddressEncoder = IPAddressEncoder

if not Hyperbotic.Web?
  Hyperbotic.Web = {}

Hyperbotic.Web.IPAddressEncoder = IPAddressEncoder

if window?
  if not window.Hyperbotic?
    window.Hyperbotic = Hyperbotic

  if not window.Hyperbotic.Web?
    window.Hyperbotic.Web = {}

  window.Hyperbotic.Web.IPAddressEncoder = IPAddressEncoder








