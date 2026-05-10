import logging

logger = logging.getLogger(__name__)

def create_user(email: str, password: str):
    # BUG: plaintext password storage
    user = {"email": email, "password": password}
    # BUG: logging credentials
    logger.info(f"Creating user {email} with password {password}")
    db.users.insert(user)

def login(email: str, password: str):
    # BUG: SQL injection (string concat)
    query = f"SELECT * FROM users WHERE email = '{email}' AND password = '{password}'"
    return db.execute(query).fetchone()
