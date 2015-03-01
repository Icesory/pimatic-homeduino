{SerialPort} = require 'serialport'
 
pageBytes = 128
 
avrUploader = (bytes, tty, cb) ->
  serial = new SerialPort tty, baudrate: 115200
 
  done = (err) ->
    serial.close ->
      cb err
 
  timer = null
  state = offset = 0
  reply = ''
 
  states = [ # Finite State Machine, one function per state
    ->
      ['0 ']
    ->
      buf = new Buffer(20)
      buf.fill 0
      buf.writeInt16BE pageBytes, 12
      ['B', buf, ' ']
    ->
      ['P ']
    ->
      state += 1  if offset >= bytes.length
      buf = new Buffer(2)
      buf.writeInt16LE offset >> 1, 0
      ['U', buf, ' ']
    ->
      state -= 2
      count = Math.min bytes.length - offset, pageBytes
      buf = new Buffer(2)
      buf.writeInt16BE count, 0
      pos = offset
      offset += count
      ['d', buf, 'F', bytes.slice(pos, offset), ' ']
    ->
      ['Q ']
  ]
 
  next = ->
    if state < states.length
      serial.write x  for x in states[state++]()
      serial.flush()
      reply = ''
      timer = setTimeout (-> done state), 300
    else
      done()
 
  serial.on 'open', next
 
  serial.on 'error', done
 
  serial.on 'data', (data) ->
    reply += data
    if reply.slice(-2) is '\x14\x10'
      clearTimeout timer
      next()