# frozen_string_literal: true

# Includes a bunch of helper methods for the chess game.
module ChessHelpers
  # Includes helper methods for Pieces' move! methods implementation.
  module MoveHelpers
    # A helper class tailored for piece movement on chess board.
    # It only supports 8 directions, 4 for straight and 4 for digonal.
    class Vector
      attr_accessor :rank, :file

      def initialize(end_rank, end_file, begin_rank = 0, begin_file = 0)
        @rank = end_rank - begin_rank
        @file = end_file - begin_file
      end

      # Transforms the vector to its corresponding unit vector.
      # Only works with staright or diagonal directions. If not, it throws an error.
      # Note that when working with diagonal directions, it gets a "unit vector" like (1, 1),
      # instead of something like (1/sqrt(2), 1/sqrt(2)), since it makes no sense in this context.
      # Specially, when working with zero vectors, it does nothing.
      def unitize
        e = StandardError.new('Exception in vector unitization: not a straight or diagonal direction.')
        throw e unless straight_or_diagonal?

        unit_vec = clone

        unit_vec.rank /= unit_vec.rank.abs unless unit_vec.rank.zero?
        unit_vec.file /= unit_vec.file.abs unless unit_vec.file.zero?
        unit_vec
      end

      def len
        [@rank.abs, @file.abs].max
      end

      def +(other)
        Vector.new(@rank + other.rank, @file + other.file)
      end

      def *(other)
        Vector.new(@rank * other, @file * other)
      end

      def straight?
        @rank.zero? || @file.zero?
      end

      def diagonal?
        @rank.abs == @file.abs
      end

      def straight_or_diagonal?
        straight? || diagonal?
      end

      # Returns true if the vector is L-shaped with borders of 1 and 2, like how a knight jumps.
      def l_shape?
        [@rank.abs, @file.abs].sort == [1, 2].freeze
      end

      def unit?
        [@rank.abs, @file.abs].max == 1
      end

      def zero?
        @rank.zero? && @file.zero?
      end

      def inspect
        "(#{@rank}, #{@file})"
      end

      def to_s
        inspect
      end

      def to_piece(board)
        board.piece_at(@rank, @file)
      end
    end

    def pos_of(piece)
      Vector.new(piece.rank, piece.file)
    end

    def direction_of(piece, tgt_rank, tgt_file)
      Vector.new(tgt_rank, tgt_file, piece.rank, piece.file)
    end

    # Includes helper methods for pieces that moves any number of squares in any straight or diagonal directions.
    # Despite its name, it's also for Rook and Bishop, since Queen is just a combination of the two in some way.
    module QueenHelpers
      def rook_reachable?(rook, tgt_rank, tgt_file)
        direction_of(rook, tgt_rank, tgt_file).straight?
      end

      def bishop_reachable?(bishop, tgt_rank, tgt_file)
        direction_of(bishop, tgt_rank, tgt_file).diagonal?
      end

      def queen_reachable?(queen, tgt_rank, tgt_file)
        rook_reachable?(queen, tgt_rank, tgt_file) || bishop_reachable?(queen, tgt_rank, tgt_file)
      end

      # Collects pieces on the path of a specific queen moving to the target square, excluding the two ends.
      # If the target square is not queen-reachable, throws a StandardError.
      def collect_path(queen, tgt_rank, tgt_file)
        board = queen.board
        pos = pos_of(queen)
        direction_vec = direction_of(queen, tgt_rank, tgt_file)
        direction_unit = direction_vec.unitize
        path = []

        (1...direction_vec.len).each do |i|
          dest = pos + direction_unit * i
          path << dest.to_piece(queen.board)
        end
        path
      end

      # Returns true if there's any piece on the path of a queen moving to the target square.
      # Also works well with rooks and bishops.
      def queen_blocked?(queen, tgt_rank, tgt_file)
        collect_path(queen, tgt_rank, tgt_file).any? { |piece| !piece.nil? }
      end
    end

    # Includes helper methods for Knight.
    module KnightHelpers
      def knight_reachable?(knight, tgt_rank, tgt_file)
        direction_of(knight, tgt_rank, tgt_file).l_shape?
      end
    end

    # Includes helper methods for King.
    module KingHelpers
      def king_reachable?(king, tgt_rank, tgt_file)
        direction_of(king, tgt_rank, tgt_file).unit?
      end
    end

    # Includes helper methods for Pawn.
    module PawnHelpers
      include QueenHelpers

      # Just assume that black pawns march at the positive-rank direction and white pawns do the opposite.
      def rank_sign(pawn)
        if pawn.player == :black
          1
        elsif pawn.player == :white
          -1
        else
          0
        end
      end

      # Verifies normal one-square march, not considering the first two-square move.
      def pawn_marchable?(pawn, tgt_rank, tgt_file)
        direction = direction_of(pawn, tgt_rank, tgt_file)
        return false unless direction.file.zero?

        direction.rank == rank_sign(pawn)
      end

      def march_blocked?(pawn, tgt_rank, tgt_file)
        queen_blocked?(pawn, tgt_rank, tgt_file)
      end

      # Verifies normal diagnal captures, not considering en passant which is handled independently.
      def pawn_capturable?(pawn, tgt_rank, tgt_file)
        return false if pawn.board.piece_at(tgt_rank, tgt_file).nil?

        direction = direction_of(pawn, tgt_rank, tgt_file)
        return false unless direction.file.abs == 1

        direction.rank == rank_sign(pawn)
      end

      # Special rule 1: pawns can choose to move 2 squares forward on its very first move only.
      def two_square_move_reachable?(pawn, tgt_rank, tgt_file)
        direction = direction_of(pawn, tgt_rank, tgt_file)
        pawn.first_move? && direction.rank == rank_sign(pawn) * 2
      end

      # Special rule 2: pawns can capture adjacent enemy pawns only if the following conditions are all satisfied:
      # 1.An opponent moves a pawn two squares forward from its starting position.
      # 2.The enemy pawn lands directly beside this pawn.
      # 3.On the very next turn only, this pawn can capture the enemy pawn and move just one square forward.
      def legal_en_passant?(pawn, tgt_rank, tgt_file)
        direction = direction_of(pawn, tgt_rank, tgt_file)
        return false unless direction.file.zero? && direction.rank == rank_sign(pawn)

        !en_passant_capture(pawn).nil?
      end

      def en_passant_capture(pawn)
        capture_arr = adjacent_pieces(pawn).select do |piece|
          piece&.en_passant_vulnerable?
        end
        capture_arr[0]
      end

      def adjacent_pieces(pawn)
        [-1, 1].map { |file_sign| adjacent_piece_on_one_side(pawn, file_sign) }
      end

      def adjacent_piece_on_one_side(pawn, file_sign)
        (pos_of(pawn) + Vector.new(0, file_sign)).to_piece(pawn.board)
      end

      def end_rank(pawn)
        (1 + rank_sign(pawn)) / 2 * (pawn.board.width - 1)
      end

      # Special rule 3: when a pawn reaches the furthest rank from its starting position, it must be promoted.
      # When a pawn is promoted, it's replaced with a Queen, Rook, Bishop, or Knight of the same color.
    end
  end
end
