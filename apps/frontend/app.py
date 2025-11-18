import streamlit as st
import requests
import time
from datetime import datetime

st.set_page_config(page_title="Network Policy Tester", layout="wide")

st.title("🔒 Network Policy Tester")
st.markdown("### Test connectivity to FastAPI backend")

# Backend URL configuration
backend_url = st.text_input(
    "Backend URL", 
    value="http://backend.backend-ns.svc.cluster.local:8000",
    help="URL of the FastAPI backend service"
)

st.divider()

# Create two columns for the buttons
col1, col2, col3 = st.columns(3)

with col1:
    if st.button("🟢 Test /allow endpoint", use_container_width=True):
        with st.spinner("Sending request to /allow..."):
            try:
                start_time = time.time()
                response = requests.get(f"{backend_url}/allow", timeout=10)
                elapsed_time = time.time() - start_time
                
                # Check if response is empty or blocked by policy
                if response.status_code == 403 or not response.text:
                    st.error(f"🚫 Blocked by L7 Network Policy! ({elapsed_time:.2f}s)")
                    st.caption(f"Status Code: {response.status_code}")
                    st.caption("Response: Empty (blocked by Cilium)")
                else:
                    st.success(f"✅ Success! ({elapsed_time:.2f}s)")
                    try:
                        st.json(response.json())
                    except:
                        st.text(response.text)
                    st.caption(f"Status Code: {response.status_code}")
                st.caption(f"Time: {datetime.now().strftime('%H:%M:%S')}")
            except requests.exceptions.Timeout:
                st.error("⏱️ Request timed out (5s)")
            except requests.exceptions.ConnectionError:
                st.error("❌ Connection failed - Network policy might be blocking")
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")

with col2:
    if st.button("🔴 Test /deny endpoint", use_container_width=True):
        with st.spinner("Sending request to /deny..."):
            try:
                start_time = time.time()
                response = requests.get(f"{backend_url}/deny", timeout=5)
                elapsed_time = time.time() - start_time
                
                # Check if response is empty or blocked by policy
                if response.status_code == 403 or not response.text:
                    st.error(f"🚫 Blocked by L7 Network Policy! ({elapsed_time:.2f}s)")
                    st.caption(f"Status Code: {response.status_code}")
                    st.caption("Response: Empty (blocked by Cilium)")
                else:
                    st.success(f"✅ Success! ({elapsed_time:.2f}s)")
                    try:
                        st.json(response.json())
                    except:
                        st.text(response.text)
                    st.caption(f"Status Code: {response.status_code}")
                st.caption(f"Time: {datetime.now().strftime('%H:%M:%S')}")
            except requests.exceptions.Timeout:
                st.error("⏱️ Request timed out (5s)")
            except requests.exceptions.ConnectionError:
                st.error("❌ Connection failed - Network policy might be blocking")
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")

with col3:
    if st.button("🏥 Test /health endpoint", use_container_width=True):
        with st.spinner("Checking backend health..."):
            try:
                start_time = time.time()
                response = requests.get(f"{backend_url}/health", timeout=5)
                elapsed_time = time.time() - start_time
                
                st.success(f"✅ Backend is healthy! ({elapsed_time:.2f}s)")
                st.json(response.json())
                st.caption(f"Status Code: {response.status_code}")
                st.caption(f"Time: {datetime.now().strftime('%H:%M:%S')}")
            except requests.exceptions.Timeout:
                st.error("⏱️ Request timed out (5s)")
            except requests.exceptions.ConnectionError:
                st.error("❌ Connection failed - Network policy might be blocking")
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")

st.divider()

# Auto-refresh section
st.markdown("### 🔄 Continuous Testing")
auto_test = st.checkbox("Enable auto-testing (every 5 seconds)")

if auto_test:
    endpoint = st.radio("Select endpoint to test:", ["/allow", "/deny", "/health"])
    
    # Placeholder for results
    result_placeholder = st.empty()
    
    while auto_test:
        try:
            start_time = time.time()
            response = requests.get(f"{backend_url}{endpoint}", timeout=5)
            elapsed_time = time.time() - start_time
            
            result_placeholder.success(f"✅ [{datetime.now().strftime('%H:%M:%S')}] Success! Response: {response.json()} ({elapsed_time:.2f}s)")
        except requests.exceptions.Timeout:
            result_placeholder.error(f"⏱️ [{datetime.now().strftime('%H:%M:%S')}] Request timed out")
        except requests.exceptions.ConnectionError:
            result_placeholder.error(f"❌ [{datetime.now().strftime('%H:%M:%S')}] Connection failed - Network policy blocking")
        except Exception as e:
            result_placeholder.error(f"❌ [{datetime.now().strftime('%H:%M:%S')}] Error: {str(e)}")
        
        time.sleep(5)

st.divider()
st.caption("💡 Use network policies to block/allow traffic and see how it affects connectivity")
