# frozen_string_literal: true

# Includes any error that may occur in the game.
module ChessErrors
  # Stores any error that occurs in Piece's move! method.
  class MoveError < StandardError
    def initialize(message: self.class.name, piece: nil, tgt_rank: nil, tgt_file: nil)
      super(message)
      @piece = piece # the piece involved in the error
      @tgt_rank = tgt_rank
      @tgt_file = tgt_file
    end

    def to_s
      if @tgt_file && @tgt_rank
        "#{super} when trying to move #{@piece.inspect} to (#{@tgt_rank}, #{@tgt_file})"
      elsif @piece
        "#{super} when trying to move #{@piece.inspect}"
      else
        super
      end
    end

    def inspect
      to_s
    end
  end

  # This error is raised when the target square is out of the piece's reach,
  # unconcerned about other pieces involved in the move.
  class OutOfReachError < MoveError
  end

  # This error is raised when some other piece is in the way of the move,
  # but not in the target square.
  class BlockedError < MoveError
  end

  # This error is raised when a piece of the same player is in the target square.
  class FriendFireError < MoveError
  end

  # This error is raised when a player is trying to move a piece that doesn't belong to him.
  class OolongError < MoveError
  end

  # This error is raised when a player is trying to make an illegal promotion.
  class PromotionError < MoveError
    def initialize(message: self.class.name, piece: nil, tgt_rank: nil, tgt_file: nil, promotion_class: nil)
      super(message: message, piece: piece, tgt_rank: tgt_rank, tgt_file: tgt_file)
      @promotion_class = promotion_class
    end

    def to_s
      if @promotion_class
        super << ", and promoting it to #{@promotion_class}"
      else
        super
      end
    end
  end
end
