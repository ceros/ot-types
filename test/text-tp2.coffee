# Tests for the TP2 capable text implementation

fs = require 'fs'
assert = require 'assert'

randomizer = require './randomizer'
{randomInt, randomReal, randomWord} = randomizer

text = require '../src/text-tp2'

describe 'text-tp2', ->
  it 'transforms sanely', ->
    tc = (op1, op2, expected, delta) ->
      if delta?
        assert.deepEqual (text.transform op1, op2, delta), expected
        assert.deepEqual (text.prune expected, op2, delta), op1
      else
        assert.deepEqual (text.transform op1, op2, 'left'), expected
        assert.deepEqual (text.prune expected, op2, 'left'), op1

        assert.deepEqual (text.transform op1, op2, 'right'), expected
        assert.deepEqual (text.prune expected, op2, 'right'), op1
    
    tc [], [], []
    tc [10], [10], [10]
    tc [{i:'hi'}], [], [{i:'hi'}]
    tc [{i:5}], [], [{i:5}]
    tc [{d:5}], [5], [{d:5}]

    tc [10], [10, {i:'hi'}], [12]
    tc [{i:'aaa'}, 10], [{i:'bbb'}, 10], [{i:'aaa'}, 13], 'left'
    tc [{i:'aaa'}, 10], [{i:'bbb'}, 10], [3, {i:'aaa'}, 10], 'right'
    tc [10, {i:5}], [{i:'hi'}, 10], [12, {i:5}]
    tc [{d:5}], [{i:'hi'}, 5], [2, {d:5}]

    tc [10], [{d:10}], [10]
    tc [{i:'hi'}, 10], [{d:10}], [{i:'hi'}, 10]
    tc [10, {i:5}], [{d:10}], [10, {i:5}]
    tc [{d:5}], [{d:5}], [{d:5}]
    
    tc [{i:'mimsy'}], [{i: 10}], [{i:'mimsy'}, 10], 'left'

  it 'normalizes', ->
    tn = (input, expected) ->
      assert.deepEqual text.normalize(input), expected
    
    tn [0], []
    tn [{i:''}], []
    tn [{d:0}], []
    tn [{i:0}], []

    tn [1, 1], [2]
    tn [2, 0], [2]

    tn [{i:4}, {i:5}], [{i:9}]
    tn [{d:4}, {d:5}], [{d:9}]
    tn [{i:4}, {d:5}], [{i:4}, {d:5}]

    tn [{i:'a'}, 0], [{i:'a'}]
    tn [{i:'a'}, {i:'b'}], [{i:'ab'}]
    tn [0, {i:'a'}, 0, {i:'b'}, 0], [{i:'ab'}]

    tn [{i:'ab'}, {i:''}], [{i:'ab'}]
    tn [{i:'ab'}, {d:0}], [{i:'ab'}]
    tn [{i:'ab'}, {i:0}], [{i:'ab'}]

    tn [{i:'a'}, 1, {i:'b'}], [{i:'a'}, 1, {i:'b'}]

  checkLengths = (doc) ->
    totalLength = doc.data.reduce ((x, y) -> x + (y.length || y)), 0
    charLength = doc.data.reduce ((x, y) -> x + (y.length || 0)), 0
    assert.strictEqual doc.charLength, charLength
    assert.strictEqual doc.totalLength, totalLength

  it 'deserializes', ->
    td = (data) ->
      doc = text.deserialize data
      assert.deepEqual doc.data, data
      checkLengths doc
    
    td []
    td ['hi']
    td [100]
    td [100, 'hi', 50, 'there']
    td [100, 'hi', 50, 'there', 30]

  it 'applies', ->
    ta = (data, op, expected) ->
      doc = text.deserialize data
      newDoc = text.apply doc, op

      assert.deepEqual newDoc.data, expected
      checkLengths newDoc

    ta [''], [{i: 5}], [5]
    ta ['abc', 1, 'defghij'], [{d:5}, 6], [5, 'efghij']

  it 'composes', ->
    tc = (op1, op2, expected) ->
      c = text.compose op1, op2
      assert.deepEqual c, expected

    tc [{i:'abcde'}], [3, {d:1}, 1], [{i:'abc'}, {i:1}, {i:'e'}]

  text.generateRandomOp = (doc) ->
    position = {index:0, offset:0}

    remainder = doc.totalLength

    newDoc = text.create()

    op = []

    {_appendDoc:appendDoc, _takeDoc:takeDoc, _append:append} = text

    addSkip = (length = Math.min(remainder, randomInt(doc.totalLength / 2) + 1)) ->
      remainder -= length

      append op, length
      while length > 0
        part = takeDoc doc, position, length
        appendDoc newDoc, part
        length -= part.length || part

    addInsert = ->
      # Insert a random word from the list
      content = if randomInt(2) then randomWord() + ' ' else randomInt(5) + 1
      append op, {i:content}
      appendDoc newDoc, content

    addDelete = ->
      length = Math.min(remainder, randomInt(doc.totalLength / 2) + 1)
      remainder -= length

      appendDoc newDoc, length
      append op, {d:length}

      while length > 0
        part = takeDoc doc, position, length
        length -= part.length || part

    r = 0.9
    while remainder > 0 and randomReal() < r
      addSkip() if randomReal() < 0.8

      r *= 0.8
      
      if randomReal() < 0.9
        if randomReal() < 0.3 then addInsert() else addDelete()
    
    addSkip(remainder) if remainder > 0

    # The code above will never insert at the end of the document. Thats important...
    addInsert() if randomReal() < 0.3

    [op, newDoc]

  text.generateRandomDoc = ->
    stringNext = randomInt(2) == 0
    data = for [0...randomInt(10)]
      stringNext = !stringNext
      if stringNext
        randomWord() + ' '
      else
        randomInt(5) + 1

    doc = text.deserialize data


  describe 'randomizer', -> it 'passes', ->
    @slow 2000
    randomizer text

