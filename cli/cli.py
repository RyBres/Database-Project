# -*- coding: utf-8 -*-
"""
@author: Ryan.Bresnahan
"""

import mysql.connector
from datetime import datetime

conn = mysql.connector.connect(
    host='localhost',
    user='appuser',
    password='apppass',
    database='customers',
    auth_plugin='mysql_native_password'
)
cursor = conn.cursor()

def register_customer():
    print("[ Registering New Customer ]")
    data = {
        "First name": input("→ First name: "),
        "Last name": input("→ Last name: "),
        "Email": input("→ Email: "),
        "Address": input("→ Home address: "),
        "Area code": input("→ Area code: "),
        "Prefix": input("→ Phone prefix: "),
        "Line": input("→ Line number: "),
        "Membership": input("→ Membership level: ")
    }
    try:
        cursor.execute("""
            INSERT INTO CUSTOMER (First_name, Surname, Email_address, Home_address, Area_code, Prefix, Line_number, Membership)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, tuple(data.values()))
        conn.commit()
        new_id = cursor.lastrowid
        print(f"✔ Customer registered successfully. Assigned Customer ID: {new_id}")
    except mysql.connector.Error as err:
        print(f"✖ Error: {err}")

def add_product_to_basket():
    print("[ Add Item to Basket ]")
    print("→ Available Products:")
    cursor.execute("SELECT Product_ID, Name, Rec_price FROM PRODUCT_ALL")
    for prod_id, name, price in cursor.fetchall():
        print(f"   • ID: {prod_id}, Name: {name}, Price: ${price:.2f}")

    cid = input("→ Customer ID: ")
    pid = input("→ Product ID: ")
    qty = int(input("→ Quantity: "))

    cursor.execute("""
        SELECT Date_created FROM BASKET
        WHERE Customer_ID = %s AND Date_closed IS NULL
        ORDER BY Date_created DESC LIMIT 1
    """, (cid,))
    basket = cursor.fetchone()

    if not basket:
        print("✖ No basket found.")
        return

    try:
        cursor.execute("""
            INSERT INTO FILLED (Date_created, Customer_ID, Product_ID, Quantity_product)
            VALUES (%s, %s, %s, %s)
        """, (basket[0], cid, pid, qty))
        conn.commit()
        print("✔ Product added to basket.")
    except mysql.connector.Error as err:
        print(f"✖ Error: {err}")

def prompt_dates():
    start = input("⏱ Start date [YYYY-MM-DD]: ")
    end = input("⏱ End date [YYYY-MM-DD]: ")
    return start, end

def show_top_customers():
    print("\n[ Top 10 Customers by Spending ]")
    start, end = prompt_dates()
    cursor.execute("""
        SELECT c.First_name, c.Surname, SUM(t.Total_amount) AS TotalSpent
        FROM CUSTOMER c
        JOIN TRANSACT t ON c.Customer_ID = t.Customer_ID
        WHERE t.Transact_date BETWEEN %s AND %s
        GROUP BY c.Customer_ID
        ORDER BY TotalSpent DESC
        LIMIT 10
    """, (start, end))
    for fname, lname, total in cursor.fetchall():
        print(f"→ {fname} {lname} | ${total:.2f}")

def show_most_frequently_sold_products():
    print("\n[ Most Frequently Sold Products ]")
    start, end = prompt_dates()
    cursor.execute("""
        SELECT filled.Product_ID, prod.Name, SUM(filled.Quantity_product) AS Total_Qty
        FROM FILLED filled
        JOIN TRANSACT tx ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
        JOIN PRODUCT_ALL prod ON filled.Product_ID = prod.Product_ID
        WHERE tx.Transact_date BETWEEN %s AND %s
        GROUP BY filled.Product_ID, prod.Name
        ORDER BY Total_Qty DESC
    """, (start, end))
    for row in cursor.fetchall():
        print("→", row)

def show_products_with_most_unique_customers():
    print("\n[ Products Sold to Most Unique Customers ]")
    start, end = prompt_dates()
    cursor.execute("""
        SELECT filled.Product_ID, prod.Name, COUNT(DISTINCT filled.Customer_ID) AS Buyer_Count
        FROM FILLED filled
        JOIN TRANSACT tx ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
        JOIN PRODUCT_ALL prod ON filled.Product_ID = prod.Product_ID
        WHERE tx.Transact_date BETWEEN %s AND %s
        GROUP BY filled.Product_ID, prod.Name
        ORDER BY Buyer_Count DESC
    """, (start, end))
    for row in cursor.fetchall():
        print("→", row)

def show_top_zip_codes():
    print("\n[ Top 5 Zip Codes by Shipments ]")
    start, end = prompt_dates()
    cursor.execute("""
        SELECT addr.Zip_code, COUNT(*) AS Num_Shipments
        FROM TRANSACT tx
        JOIN SHIP_CUST sc ON sc.Customer_ID = tx.Customer_ID
        JOIN SHIP_ADDR addr ON addr.Addr_name = sc.Addr_name
        WHERE tx.Transact_date BETWEEN %s AND %s
        GROUP BY addr.Zip_code
        ORDER BY Num_Shipments DESC
        LIMIT 5
    """, (start, end))
    for row in cursor.fetchall():
        print("→", row)

def show_average_product_price_by_type():
    print("\n[ Average Selling Price per Product Type ]")
    start, end = prompt_dates()
    cursor.execute("""
        SELECT prod.Product_type,
               ROUND(AVG(filled.Final_price / filled.Quantity_product), 2) AS Avg_Price
        FROM FILLED filled
        JOIN TRANSACT tx ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
        JOIN PRODUCT_ALL prod ON filled.Product_ID = prod.Product_ID
        WHERE tx.Transact_date BETWEEN %s AND %s
        GROUP BY prod.Product_type
        ORDER BY Avg_Price DESC
    """, (start, end))
    for row in cursor.fetchall():
        print("→", row)
        
def place_order():
    print("\n[ Place Order ]")
    cid = input("→ Customer ID: ")

    # Get the active basket
    cursor.execute("""
        SELECT Date_created, Total_amount, Quantity_items FROM BASKET
        WHERE Customer_ID = %s AND Date_closed IS NULL
        ORDER BY Date_created DESC LIMIT 1
    """, (cid,))
    basket = cursor.fetchone()

    if not basket:
        print("✖ No active basket found.")
        return

    date_created, total, qty = basket

    cc = input("→ Credit card number used: ")
    delivered = False
    ship_date = datetime.now().strftime('%Y-%m-%d')
    deliver_date = None

    try:
        # Insert old basket to transact
        cursor.execute("""
            INSERT INTO TRANSACT (
                Transact_ID, Transact_date, Total_amount, Num_items, Credit_card,
                Delivered_tag, Deliver_date, Ship_date, Date_created, Customer_ID
            )
            VALUES (
                NULL, NOW(), %s, %s, %s,
                %s, %s, %s, %s, %s
            )
        """, (total, qty, cc, delivered, deliver_date, ship_date, date_created, cid))

        # Close basket
        cursor.execute("""
            UPDATE BASKET SET Date_closed = NOW()
            WHERE Customer_ID = %s AND Date_created = %s
        """, (cid, date_created))

        conn.commit()
        print("✔ Order placed successfully.")
    except mysql.connector.Error as err:
        print(f"✖ Error: {err}")
        
        
def view_transaction_history():
    print("\n[ View Transaction History ]")
    cid = input("→ Customer ID: ")

    query = """
        SELECT t.Transact_ID, c.First_name, c.Surname, p.Name, f.Quantity_product, f.Final_price,
               t.Transact_date, t.Delivered_tag
        FROM TRANSACT t
        JOIN CUSTOMER c ON t.Customer_ID = c.Customer_ID
        JOIN FILLED f ON f.Date_created = t.Date_created AND f.Customer_ID = t.Customer_ID
        JOIN PRODUCT_ALL p ON f.Product_ID = p.Product_ID
        WHERE 1=1
    """
    params = []

    if cid:
        query += " AND c.Customer_ID = %s"
        params.append(int(cid))

    cursor.execute(query, tuple(params))
    rows = cursor.fetchall()

    if not rows:
        print("✖ No matching transactions found.")
        return

    for row in rows:
        print(row)


def goto_statistics():
    while True:
        print("""
        ═══════════════════════════════
        📊 STATISTICS SUB-MENU 📊
        ═══════════════════════════════
        [A] Most frequently sold products
        [B] Products sold to most unique customers
        [C] Top 10 customers by spending
        [D] Top 5 zip codes by shipments
        [E] Average price per product type
        [X] Return to main menu
        ═══════════════════════════════""")
        match input("Choose (A–E or X): ").strip():
            case 'A': show_most_frequently_sold_products()
            case 'B': show_products_with_most_unique_customers()
            case 'C': show_top_customers()
            case 'D': show_top_zip_codes()
            case 'E': show_average_product_price_by_type()
            case 'X': break
            case _: print("Invalid selection. Try again.")

def main_menu():
    while True:
        print("""
        ═══════════════════════════════
        🛒 CUSTOMERS DB MENU 🛒
        ═══════════════════════════════
        [A] Register a new customer
        [B] Add product to basket
        [C] Place order
        [D] View transaction history
        [E] View statistics
        [X] Exit
        ═══════════════════════════════""")
        choice = input("Select option (A–C or X): ").strip().upper()
        match choice:
            case 'A': register_customer()
            case 'B': add_product_to_basket()
            case 'C': place_order() 
            case 'D': view_transaction_history() 
            case 'E': goto_statistics()
            case 'X': print("👋 Goodbye!"); break

# Run routine
main_menu()
cursor.close()
conn.close()