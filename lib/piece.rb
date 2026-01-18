# frozen_string_literal: true

require_relative 'utils/chess_errors'
require_relative 'utils/chess_helpers'

# Includes Piece's methods in charge of verifying whether a move is legal.
module MoveVerifier
  include ChessHelpers::MoveHelpers
  include ChessErrors

  # Collects all verifying methods needed.
  def verify_legality(tgt_rank, tgt_file, **kw_args)
    verify_reach(tgt_rank, tgt_file)
    verify_blocked(tgt_rank, tgt_file)
    verify_capture(tgt_rank, tgt_file)
    verify_side_effects(tgt_rank, tgt_file, **kw_args)
  end

  def verify_reach(tgt_rank, tgt_file)
    return true if reachable?(tgt_rank, tgt_file)

    throw OutOfReachError.new(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file)
  end

  def verify_blocked(tgt_rank, tgt_file)
    return true unless blocked?(tgt_rank, tgt_file)

    throw BlockedError.new(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file)
  end

  def verify_capture(tgt_rank, tgt_file)
    capture = capture_at(tgt_rank, tgt_file)
    return if capture.nil?
    raise FriendFireError.new(piece: self, tgt_rank: tgt_rank, tgt_file: tgt_file) if capture.player == @player

    true
  end

  # In most cases, only the following verifying helpers should be overridden.
  def verify_side_effects(tgt_rank, tgt_file, **kw_args) end

  def reachable?(_tgt_rank, _tgt_file)
    true
  end

  def blocked?(_tgt_rank, _tgt_file)
    false
  end

  def capture_at(tgt_rank, tgt_file)
    @board.piece_at(tgt_rank, tgt_file)
  end
end

# An object that manages how a piece can move and display.
class Piece
  include MoveVerifier

  attr_accessor :board, :rank, :file, :player

  def initialize(board, rank, file, player)
    @board = board
    @rank = rank
    @file = file
    @player = player

    board.add(@rank, @file, self)
  end

  # Pieces' representations on board are defined as followed.
  # Derived classes should at least override the black & white symbol.
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
  # Accepts extra keyword arguments for side effects like pawn promotion.
  def move!(tgt_rank, tgt_file, **kw_args)
    # Verifies if the move to the target square is legal according to the Chess rules.
    # If not, throws an error.
    verify_legality(tgt_rank, tgt_file, **kw_args)

    # Carries out side effects before the move actually happens.
    # e.g.: pawns capture en-passants.
    pre_side_effects!(tgt_rank, tgt_file, **kw_args)

    # Removes itself from the original square.
    remove

    # Adds itself to the target square.
    # Note that it can be seen as a capture if there's a enemy piece in the target square.
    @board.add(tgt_rank, tgt_file, self)

    # Updates positional state.
    @rank = tgt_rank
    @file = tgt_file

    # Carries out side effects after the move happens.
    # e.g.: pawns promote.
    post_side_effects!(tgt_rank, tgt_file, **kw_args)
    true
  end

  def remove
    @board.remove(@rank, @file)
  end

  def pre_side_effects!(tgt_rank, tgt_file, **kw_args) end

  def post_side_effects!(tgt_rank, tgt_file, **kw_args) end

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
  include QueenHelpers

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
  include KnightHelpers

  def black_symbol
    '♞'
  end

  def white_symbol
    '♘'
  end

  def reachable?(tgt_rank, tgt_file)
    knight_reachable?(self, tgt_rank, tgt_file)
  end
end

# Manages a single King,
# which moves one square in any direction.
# TODO: explains check, checkmate, stalement and castling.
class King < Piece
  include KingHelpers

  def black_symbol
    '♚'
  end

  def white_symbol
    '♔'
  end

  def reachable?(tgt_rank, tgt_file)
    king_reachable?(self, tgt_rank, tgt_file)
  end
end

# Manages a single Pawn,
# which moves forward one square (but never backward).
# On its first move only, it may move forward two squares.
# It captures diagonally forward one square.
class Pawn < Piece
  include PawnHelpers
  PROMOTABLE_CLASSES = [Queen, Rook, Bishop, Knight].freeze

  attr_accessor :has_moved, :is_en_passant_vulnerable

  def initialize(board, rank, file, player, has_moved: false, is_en_passant_vulnerable: false) # rubocop:disable Metrics/ParameterLists
    super(board, rank, file, player)
    @has_moved = has_moved
    @is_en_passant_vulnerable = is_en_passant_vulnerable
  end

  def black_symbol
    '♟'
  end

  def white_symbol
    '♙'
  end

  def reachable?(tgt_rank, tgt_file)
    pawn_marchable?(self, tgt_rank, tgt_file) ||
      pawn_capturable?(self, tgt_rank, tgt_file) ||
      two_square_move_reachable?(self, tgt_rank, tgt_file)
  end

  def blocked?(tgt_rank, tgt_file)
    march_blocked?(self, tgt_rank, tgt_file)
  end

  def pre_side_effects!(tgt_rank, tgt_file, **)
    en_passant! if legal_en_passant?(self, tgt_rank, tgt_file)
  end

  # There's clearly a bug that if the player never moves the pawn after it takes a two-square move,
  # the pawn remains the en-passant-vulnerable state.
  # However, i don't know how to elegantly fix it for now.
  # TODO: fix the bug.
  def post_side_effects!(tgt_rank, tgt_file, promotion_class: nil, **)
    promote_to!(promotion_class) if promotable?(promotion_class)

    @has_moved = true
    @is_en_passant_vulnerable = two_square_move_reachable?(self, tgt_rank, tgt_file)
  end

  def first_move?
    !@has_moved
  end

  def en_passant_vulnerable?
    @is_en_passant_vulnerable
  end

  def promote_to!(promotion_class)
    promotion_class.new(@board, @rank, @file, @player)
  end

  def promotable?(promotion_class)
    @rank == end_rank(self) && promotion_class in PROMOTABLE_CLASSES
  end

  # Oh no I misunderstand en passant's rules, the pawn should move diagonally after capturing instead of going forward.
  # TODO: fix this silly mistake.
  def en_passant!
    en_passant_capture(self).remove
  end
end
