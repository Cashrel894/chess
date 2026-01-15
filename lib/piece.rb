# frozen_string_literal: true

# An object that manages how a piece can move and display.
class Piece
  BLACK_SYMBOL = '🦀'
  WHITE_SYMBOL = '🐌'
  FALLBACK_SYMBOL = '🐈'

  attr_accessor :player

  def initialize(board, rank, file, player)
    @board = board
    @rank = rank
    @file = file
    @player = player
  end

  # The core method of Piece class, and it should be implemented by its derived classes.
  # First, verifies whether the move towards the target square is legal.
  # If it is, carries out the move by changing the game state.
  # If not, raises a MoveError that should be handled by the caller.
  def move!(tgt_rank, tgt_file)
    verify_legality(tgt_rank, tgt_file)

    @board.remove(@rank, @file)
    @board.add(tgt_rank, tgt_file, self)
  end

  def verify_legality(tgt_rank, tgt_file)
    verify_path(tgt_rank, tgt_file)
    verify_capture(tgt_rank, tgt_file)
  end

  def verify_path(tgt_rank, tgt_file) end

  def verify_capture(tgt_rank, tgt_file)
    capture = @board.piece_at(tgt_rank, tgt_file)

    return if capture.nil?
    raise FriendFireError if capture.player == @player
  end

  # For now, pieces' outlooks are hard-coded at such an early development stage.
  # Player symbols are alike.
  def to_s
    if player == :black
      BLACK_SYMBOL
    elsif player == :white
      WHITE_SYMBOL
    else
      FALLBACK_SYMBOL
    end
  end

  def inspect
    "<#{player}'s #{self.class.name} at (#{rank}, #{file})>"
  end
end

# The derived classes are as follows
# TODO: split them into independent files

# Manages a single Rook,
# which moves any number of squares horizonally or vertically.
class Rook < Piece
end

# Manages a single Bishop,
# which moves any number of squares diagonally.
class Bishop < Piece
end

# Manages a single Knight,
# which moves in an "L" shape: two squares in one direction, then one square perpendicular.
# It can jump over other pieces.
class Knight < Piece
end

# Manages a single Queen,
# which moves any number of squares in any straight or diagonal direction.
class Queen < Piece
end

# Manages a single King,
# which moves one square in any direction.
# TODO: explains check, checkmate, stalement and castling.
class King < Piece
end

# Manages a single Pawn,
# which moves forward one square (but never backward).
# On its first move only, it may move forward two squares.
# It captures diagonally forward one square.
class Pawn < Piece
end
