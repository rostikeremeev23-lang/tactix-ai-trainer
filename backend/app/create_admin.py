"""Interactively create the first TACTIX organization administrator."""
from __future__ import annotations

import argparse
import getpass

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.db import get_session_factory
from app.models import Organization, OrganizationMembership, User
from app.auth import password_hasher


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a TACTIX organization and its first admin.")
    parser.add_argument("--email", required=True)
    parser.add_argument("--first-name", required=True)
    parser.add_argument("--callsign", required=True)
    parser.add_argument("--organization", required=True)
    args = parser.parse_args()
    email = args.email.strip().lower()
    password = getpass.getpass("Admin password (12+ characters): ")
    confirmation = getpass.getpass("Repeat password: ")
    if len(password) < 12 or len(password) > 128 or password != confirmation:
        parser.error("Passwords must match and contain 12 to 128 characters.")
    factory = get_session_factory()
    with factory() as db:
        if db.scalar(select(User.id).where(User.email == email)) is not None:
            parser.error("That email is already registered.")
        try:
            organization = Organization(name=args.organization.strip())
            user = User(
                email=email,
                password_hash=password_hasher.hash(password),
                first_name=args.first_name.strip(),
                callsign=args.callsign.strip(),
            )
            db.add_all([organization, user])
            db.flush()
            db.add(OrganizationMembership(
                organization_id=organization.id,
                user_id=user.id,
                role="admin",
            ))
            db.commit()
        except IntegrityError:
            db.rollback()
            parser.error("Could not create the admin with the supplied details.")
    print(f"Created admin {email} for organization {args.organization.strip()!r}.")


if __name__ == "__main__":
    main()
