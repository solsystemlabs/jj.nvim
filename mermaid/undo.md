# Undo Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press u| C[Undo Last Operation]
    B -->|Press U| D[Undo Menu Options]
    B -->|leader+a action menu| E[Action Menu]
    
    %% Undo Last Operation (simple)
    C --> F[undo_last]
    F --> G[Build jj undo command]
    G --> H[jj undo]
    
    %% Undo Menu Options
    D --> I[Show undo options menu]
    I --> J{Select Option}
    
    J -->|l| K[Undo last operation]
    J -->|o| L[Undo specific operation]
    J -->|s| M[Show operation history]
    
    %% Undo Last
    K --> N[undo_last]
    N --> O[Build jj undo command]
    O --> P[jj undo]
    
    %% Undo Specific Operation
    L --> Q[Show operation selection]
    Q --> R[Display operation history]
    R --> S[Select operation to undo]
    S --> T[undo_operation operation_id]
    T --> U[Build jj undo command]
    U --> V[jj undo --operation operation_id]
    
    %% Show Operation History
    M --> W[Build jj op log command]
    W --> X[jj op log]
    X --> Y[Display operation log]
    Y --> Z[Show operation details]
    
    %% Action Menu Flow
    E --> AA{Menu Selection}
    AA -->|Global Action| BB[Undo last u]
    BB --> F
    
    %% Common Execution Path
    H --> CC[commands.execute_with_immutable_prompt]
    P --> CC
    V --> CC
    X --> DD[commands.execute_with_immutable_prompt]
    
    CC --> EE[Execute jj command]
    DD --> FF[Execute jj command]
    
    EE --> GG{Success?}
    FF --> HH{Success?}
    
    GG -->|Yes| II[Show success notification]
    GG -->|No| JJ[Show error message]
    
    HH -->|Yes| KK[Parse operation log]
    HH -->|No| LL[Show error message]
    
    %% Success Path - Undo
    II --> MM[Show undo result]
    MM --> NN[Refresh log display]
    NN --> OO[Update commit graph]
    OO --> PP[Show operation summary]
    
    %% Success Path - Operation Log
    KK --> QQ[Format operation history]
    QQ --> RR[Create operation buffer]
    RR --> SS[Display operation log]
    SS --> TT[Enable operation selection]
    
    %% Operation Log Buffer
    RR --> UU[Set buffer options]
    UU --> VV[buftype=nofile]
    VV --> WW[modifiable=false]
    WW --> XX[filetype=jj-oplog]
    
    XX --> YY[Apply operation log syntax]
    YY --> ZZ[Set operation log keymaps]
    ZZ --> AAA[Show operation window]
    
    %% Operation Selection
    TT --> BBB[Operation selection mode]
    BBB --> CCC[Highlight selected operation]
    CCC --> DDD[Enter to confirm]
    DDD --> EEE[Extract operation ID]
    EEE --> T
    
    %% Operation Log Keymaps
    ZZ --> FFF[Set operation buffer keymaps]
    FFF --> GGG[q - close operation log]
    GGG --> HHH[Enter - select operation]
    HHH --> III[j/k - navigate operations]
    III --> JJJ[? - show help]
    
    %% Error Handling
    JJ --> KKK[Return to previous state]
    LL --> KKK
    
    %% Validation
    F --> LLL{Repository State?}
    N --> LLL
    T --> MMM{Valid Operation?}
    
    LLL -->|No History| NNN[Show error - no operations to undo]
    LLL -->|Valid| G
    
    MMM -->|Invalid| OOO[Show error - invalid operation]
    MMM -->|Valid| U
    
    NNN --> KKK
    OOO --> KKK
    
    %% Operation Details
    Z --> PPP[Show operation metadata]
    PPP --> QQQ[Operation timestamp]
    QQQ --> RRR[Operation type]
    RRR --> SSS[Operation description]
    SSS --> TTT[Changed commits]
    
    %% Undo Result Display
    MM --> UUU[Show what was undone]
    UUU --> VVV[Display affected commits]
    VVV --> WWW[Show repository state change]
    WWW --> XXX[Update status information]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef buffer fill:#f3e5f5
    classDef validation fill:#fff3e0
    
    class A,B,C,D,E userAction
    class I,J,Q,R,S,AA,BB,BBB,CCC,DDD,EEE menuAction
    class F,N,T,G,O,U,CC,DD,EE,FF execution
    class H,P,V,W,X command
    class II,KK,MM,NN,OO,PP,QQ,RR,SS,TT,UUU,VVV,WWW,XXX success
    class JJ,LL,KKK,NNN,OOO error
    class RR,UU,VV,WW,XX,YY,ZZ,AAA,FFF,GGG,HHH,III,JJJ buffer
    class LLL,MMM validation
```

## Key Menu Options

- **l**: Undo last operation (same as simple `u`)
- **o**: Undo specific operation (interactive selection)
- **s**: Show operation history (browse without undoing)

## Command Variations

- **Last**: `jj undo` - undoes the most recent operation
- **Specific**: `jj undo --operation <operation_id>` - undoes specific operation
- **History**: `jj op log` - shows operation history for browsing

## Advanced Features

- **Operation History**: Interactive browsing of all operations
- **Selective Undo**: Undo any operation from history, not just the last
- **Operation Details**: Shows timestamps, types, and affected commits
- **Safe Validation**: Prevents invalid undo operations

## Operation Log Features

- **Interactive Buffer**: Browse operations with syntax highlighting
- **Operation Metadata**: Timestamps, types, descriptions
- **Commit Tracking**: Shows which commits were affected
- **Selection Mode**: Choose specific operations to undo

## Safety Features

- **Validation**: Ensures operations exist and are valid to undo
- **Confirmation**: Shows what will be undone before executing
- **Error Handling**: Clear messages for invalid operations
- **State Checking**: Verifies repository state before undo

## File Locations

- **Core**: `lua/jj-nvim/jj/undo.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:563-565`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:177-181`
- **Keybindings**: `u` for undo last, `U` for undo menu