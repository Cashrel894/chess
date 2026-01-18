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

    def pos_vec
      Vector.new(@rank, @file)
    end

    def direction_to(tgt_rank, tgt_file)
      Vector.new(tgt_rank, tgt_file, @rank, @file)
    end

    # Collects pieces on the path of a specific piece moving to the target square straightly or diagonally,
    # excluding the two ends.
    # If the direction to the target square is not straight or diagonal, throws a StandardError.
    def collect_path(tgt_rank, tgt_file)
      pos = pos_vec
      direction_vec = direction_to(tgt_rank, tgt_file)
      direction_unit = direction_vec.unitize
      path = []

      (1...direction_vec.len).each do |i|
        dest = pos + direction_unit * i
        path << dest.to_piece(@board)
      end
      path
    end

    # Returns true if there's any piece on a specific straight or diagnol path,
    # exluding the two ends.
    def straight_or_diagonal_blocked?(tgt_rank, tgt_file)
      collect_path(tgt_rank, tgt_file).any? { |piece| !piece.nil? }
    end

    # Includes helper methods for pieces that moves any number of squares in any straight or diagonal directions.
    # Despite its name, it's also for Rook and Bishop, since Queen is just a combination of the two in some way.
    module QueenHelpers
      def rook_reachable?(tgt_rank, tgt_file)
        direction_to(tgt_rank, tgt_file).straight?
      end

      def bishop_reachable?(tgt_rank, tgt_file)
        direction_to(tgt_rank, tgt_file).diagonal?
      end

      def queen_reachable?(tgt_rank, tgt_file)
        rook_reachable?(tgt_rank, tgt_file) || bishop_reachable?(tgt_rank, tgt_file)
      end
    end

    # Includes helper methods for Knight.
    module KnightHelpers
      def knight_reachable?(tgt_rank, tgt_file)
        direction_to(tgt_rank, tgt_file).l_shape?
      end
    end

    # Includes helper methods for King.
    module KingHelpers
      def king_reachable?(tgt_rank, tgt_file)
        direction_to(tgt_rank, tgt_file).unit?
      end
    end

    # Includes helper methods for Pawn.
    module PawnHelpers
      def rank_sign
        self.class::RANK_SIGN[@player] || 1
      end

      # Verifies normal one-square march, not considering the first two-square move.
      def legal_pawn_march?(tgt_rank, tgt_file)
        direction = direction_to(tgt_rank, tgt_file)

        direction.file.zero? && direction.rank == rank_sign
      end

      # Verifies normal diagnal captures, not considering en passant which is handled independently.
      def legal_pawn_capture?(tgt_rank, tgt_file)
        direction = direction_to(tgt_rank, tgt_file)

        !@board.piece_at(tgt_rank, tgt_file).nil? &&
          direction.file.abs == 1 &&
          direction.rank == rank_sign
      end

      def march_blocked?(tgt_rank, tgt_file)
        straight_or_diagonal_blocked?(tgt_rank, tgt_file)
      end

      # Special rule 1: pawns can choose to move 2 squares forward on its very first move only.
      def legal_two_square_move?(tgt_rank, tgt_file)
        direction = direction_to(tgt_rank, tgt_file)
        first_move? && direction.rank == rank_sign * 2
      end

      def first_move?
        !@has_moved
      end

      # Special rule 2: pawns can capture adjacent enemy pawns only if the following conditions are all satisfied:
      # 1.An opponent moves a pawn two squares forward from its starting position.
      # 2.The enemy pawn lands directly beside this pawn.
      # 3.On the very next turn only, this pawn can capture the enemy pawn and move just one square forward.
      def legal_en_passant?(tgt_rank, tgt_file)
        direction = direction_to(tgt_rank, tgt_file)

        direction.file.abs == 1 &&
          direction.rank == rank_sign &&
          !en_passant_capture(tgt_file).nil?
      end

      def en_passant_take!(tgt_file)
        en_passant_capture(tgt_file).remove
      end

      def en_passant_capture(tgt_file)
        adjacent_piece = @board.piece_at(@rank, tgt_file)

        adjacent_piece if adjacent_piece.is_a?(self.class) &&
                          adjacent_piece.en_passant_vulnerable?
      end

      def en_passant_vulnerable?
        @is_en_passant_vulnerable
      end

      # Special rule 3: when a pawn reaches the furthest rank from its starting position, it must be promoted.
      # When a pawn is promoted, it's replaced with a Queen, Rook, Bishop, or Knight of the same color.
      def end_rank
        (1 + rank_sign) / 2 * (@board.width - 1)
      end

      def promote_to!(promotion_class)
        promotion_class.new(@board, @rank, @file, @player)
      end

      def legal_promotion?(promotion_class)
        @rank == end_rank && self.class::PROMOTABLE_CLASSES.include?(promotion_class)
      end
    end
  end
end
