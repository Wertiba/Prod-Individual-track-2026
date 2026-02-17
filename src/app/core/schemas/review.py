from enum import Enum


class ReviewResult(str, Enum):
    APPROVED = 'APPROVED'
    IMPROVEMENT = 'IMPROVEMENT'
    REJECTED = 'REJECTED'
