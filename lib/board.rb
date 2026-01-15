# frozen_string_literal: true

# A 8*8 grid that manages the current game state.
class Board
  BOARD_WIDTH = 8
  PLACEHOLDER_CHAR = ' '

  def initialize
    @grid = Array.new(BOARD_WIDTH) { Array.new(BOARD_WIDTH, nil) }
  end

  def piece_at(rank, file)
    @grid[rank][file]
  end

  def add(rank, file, piece)
    @grid[rank][file] = piece
  end

  def remove(rank, file)
    @grid[rank][file] = nil
  end

  def to_s
    str = ''
    @grid.each do |row|
      row.each do |piece|
        str += piece.nil? ? PLACEHOLDER_CHAR : piece
      end
      str += "\n"
    end
    str
  end

  def inspect
    str = "Board Object:\n"
    @grid.flatten.each do |piece|
      next if piece.nil?

      str += "#{piece}\n"
    end
    str
  end
end
