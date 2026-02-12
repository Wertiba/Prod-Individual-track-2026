from fastapi import APIRouter, Response, status

from app.api.v1.dependencies import AuthServiceDep, UserServiceDep
from app.api.v1.utils import set_auth_cookies
from app.core.schemas.user import UserCreateBody, UserLoginBody, UserWithTokenResponse

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=UserWithTokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    auth_service: AuthServiceDep, user_service: UserServiceDep, user: UserCreateBody, response: Response
) -> UserWithTokenResponse:
    result = await user_service.register(user)
    tokens = auth_service.create_tokens_for_user(result)
    set_auth_cookies(response, tokens=tokens)

    return UserWithTokenResponse(user=result.model_dump(), **tokens.model_dump())


@router.post("/login", response_model=UserWithTokenResponse, status_code=status.HTTP_200_OK)
async def login(
    auth_service: AuthServiceDep,
    user_data: UserLoginBody,
    response: Response,
) -> UserWithTokenResponse:
    result = await auth_service.login_user(user_data)
    set_auth_cookies(response, access_token=result.accessToken)
    return result
