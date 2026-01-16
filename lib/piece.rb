# frozen_string_literal: true

require_relative 'utils/chess_errors'
require_relative 'utils/chess_helpers'

# Includes Piece's methods in charge of verifying whether a move is legal.
module MoveVerifier
  def verify_legality(tgt_rank, tgt_file)
    verify_path(tgt_rank, tgt_file)
    verify_capture(tgt_rank, tgt_file)
  end

  def verify_path(tgt_rank, tgt_file)
    verify_reach(tgt_rank, tgt_file)
    verify_blocked(tgt_rank, tgt_file)
  end

  def verify_reach(tgt_rank, tgt_file)
    return true if reachable?(tgt_rank, tgt_file)

    throw OutOfReachError(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file)
  end

  def reachable?(tgt_rank, tgt_file)
    true
  end

  def verify_blocked(tgt_rank, tgt_file)
    return true unless blocked?(tgt_rank, tgt_file)

    throw BlockedError(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file)
  end

  def blocked?(tgt_rank, tgt_file)
    false
  end

  def verify_capture(tgt_rank, tgt_file)
    capture = @board.piece_at(tgt_rank, tgt_file)

    return if capture.nil?
    raise FriendFireError.new(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file) if capture.player == @player

    true
  end
end

# An object that manages how a piece can move and display.
class Piece
  include MoveVerifier
  include ChessErrors

  attr_accessor :board, :rank, :file, :player

  def initialize(board, rank, file, player)
    @board = board
    @rank = rank
    @file = file
    @player = player

    board.add(@rank, @file, self)
  end

  def black_symbol
    '🦀'
  end

  def white_symbol
    '🐌'
  end

  def fallback_symbol
    '🐈'
  end

  # The core method of Piece class, and it should be implemented by its derived classes.
  # First, verifies whether the move towards the target square is legal.
  # If it is, carries out the move by changing the game state.
  # If not, raises a MoveError that should be handled by the caller.
  def move!(tgt_rank, tgt_file)
    verify_legality(tgt_rank, tgt_file)

    @board.remove(@rank, @file)
    @board.add(tgt_rank, tgt_file, self)

    @rank = tgt_rank
    @file = tgt_file
    true
  end

  # For now, pieces' outlooks are hard-coded at such an early development stage.
  # Player symbols are alike.
  def to_s
    if player == :black
      black_symbol
    elsif player == :white
      white_symbol
    else
      fallback_symbol
    end
  end

  def inspect
    "<#{@player}'s #{self.class.name} at (#{@rank}, #{@file})>"
  end
end

# The derived classes are as follows
# TODO: split them into independent files

# Manages a single Queen,
# which moves any number of squares in any straight or diagonal direction.
class Queen < Piece
  include ChessHelpers::MoveHelpers::QueenHelpers

  def black_symbol
    '♛'
  end

  def white_symbol
    '♕'
  end

  def reachable?(tgt_rank, tgt_file)
    queen_reachable?(self, tgt_rank, tgt_file)
  end

  def blocked?(tgt_rank, tgt_file)
    queen_blocked?(self, tgt_rank, tgt_file)
  end
end

# Manages a single Rook,
# which moves any number of squares horizonally or vertically.
class Rook < Queen
  def black_symbol
    '♜'
  end

  def white_symbol
    '♖'
  end

  def reachable?(tgt_rank, tgt_file)
    rook_reachable?(self, tgt_rank, tgt_file)
  end
end

# Manages a single Bishop,
# which moves any number of squares diagonally.
class Bishop < Queen
  def black_symbol
    '♝'
  end

  def white_symbol
    '♗'
  end

  def reachable?(tgt_rank, tgt_file)
    bishop_reachable?(self, tgt_rank, tgt_file)
  end
end

# Manages a single Knight,
# which moves in an "L" shape: two squares in one direction, then one square perpendicular.
# It can jump over other pieces.
class Knight < Piece
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
