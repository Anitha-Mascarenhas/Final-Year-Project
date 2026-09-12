from pydantic import BaseModel, EmailStr, Field
from datetime import date
from typing import Optional


class ParentSignupRequest(BaseModel):
    childName: str = Field(min_length=1)
    dob: date
    email: Optional[EmailStr] = None
    password: str = Field(min_length=8)
    confirmPassword: str


class HealthWorkerSignupRequest(BaseModel):
    name: str = Field(min_length=1)
    email: Optional[EmailStr] = None
    password: str = Field(min_length=8)
    confirmPassword: str


class ParentLoginRequest(BaseModel):
    childId: str
    password: str


class HealthWorkerLoginRequest(BaseModel):
    workerId: str
    password: str