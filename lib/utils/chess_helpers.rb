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
          path << board.piece_at(dest.rank, dest.file)
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

    # Includes helpers methods for King.
    module KingHelpers
      def king_reachable?(king, tgt_rank, tgt_file)
        direction_of(king, tgt_rank, tgt_file).unit?
      end
    end

    module PawnHelpers
    end
  end
end
